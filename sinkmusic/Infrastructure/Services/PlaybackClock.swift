//
//  PlaybackClock.swift
//  sinkmusic
//
//  Infrastructure — el reloj autoritativo de la reproducción.
//

import Foundation
import QuartzCore

/// Lo que el reloj concluye en un tick.
enum PlaybackClockTick: Equatable, Sendable {

    /// Situación normal: la posición vigente.
    case progress(PlaybackProgress)

    /// La pista llegó al final de su duración.
    case reachedEnd(PlaybackProgress)

    /// El motor lleva demasiado tiempo sin entregar un solo frame nuevo aunque se le dio
    /// orden de reproducir. Se informa una sola vez por atasco.
    case stalled(PlaybackProgress)
}

/// Reloj autoritativo de la reproducción.
///
/// **Por qué existe.** `AVAudioEngine` es una API de grafo: no tiene el concepto de "pista",
/// no expone posición ni duración y no tiene estado "terminó" — solo buffers. Todo eso hay
/// que construirlo encima, y el error clásico es construirlo en varios sitios a la vez: el
/// motor cuenta frames, la UI lleva su propio contador y `MPNowPlayingInfoCenter` extrapola
/// con el reloj de pared entre un push y el siguiente. En cuanto uno de los tres se desvía,
/// los tres muestran cosas distintas.
///
/// Este tipo es la única fuente: traduce los frames que el motor dice haber renderizado a
/// una `PlaybackProgress` acotada, y todo lo demás (UI, pantalla de bloqueo, Live Activity,
/// persistencia) la lee de aquí sin recalcular nada.
///
/// **Qué vigila.** El motor puede fallar de dos formas opuestas, y las dos son invisibles
/// desde su API:
///
/// - *Pasarse*: un `AVAudioPlayerNode` al que se le acaban los buffers programados **no se
///   detiene**. Sigue en estado "playing" renderizando silencio y su posición crece sin
///   límite. Si además se pierde el aviso de fin de pista — iOS descarta los buffers
///   programados al reconfigurar la sesión de audio, típicamente con la app en segundo
///   plano — nadie se entera de que la canción acabó.
/// - *Atascarse*: el motor se para y deja de entregar frames, pero sin emitir ninguna
///   notificación de ruta ni de configuración a la que reaccionar.
///
/// Comparar la posición real contra la duración real cubre el primer caso; medir cuánto
/// hace que la posición no avanza cubre el segundo. Ambas son consecuencias directas de la
/// misma fuente de verdad, no comprobaciones sueltas.
///
/// El reloj es una máquina de estados pura: no toca `AVFoundation` ni temporizadores. Quien
/// lo usa le pasa la posición cruda del motor y el instante actual, lo que lo hace
/// comprobable sin audio real.
@MainActor
final class PlaybackClock {

    /// Margen sobre la duración a partir del cual la pista se da por terminada.
    ///
    /// No es cero para que el aviso de fin del propio motor, que es más preciso, gane
    /// siempre la carrera cuando llega; este camino es el que queda cuando no llega.
    static let endOfTrackTolerance: TimeInterval = 0.25

    /// Tiempo sin un solo frame nuevo antes de declarar el motor atascado.
    ///
    /// Holgadamente mayor que `endOfTrackTolerance`: al final de la pista la posición se
    /// acota a la duración y deja de avanzar, y ese caso debe resolverse como fin de pista,
    /// nunca como atasco.
    static let stallTimeout: TimeInterval = 1.0

    /// Avance mínimo para considerar que el motor sigue entregando audio. Por debajo de
    /// esto es ruido de redondeo del reloj de render, no progreso.
    private static let advanceEpsilon: TimeInterval = 0.001

    // MARK: - Estado

    private(set) var duration: TimeInterval = 0
    private(set) var elapsed: TimeInterval = 0

    /// La pista llegó a su final y el motor no tiene nada programado. Mientras sea `true`,
    /// darle orden de reproducir solo renderizaría silencio.
    private(set) var hasReachedEnd = false

    /// Instante (reloj monótono) del último avance real. Base del detector de atasco.
    private var lastAdvanceAt: CFTimeInterval = 0

    /// El atasco en curso ya se informó: no se repite hasta que la posición vuelva a avanzar
    /// o alguien reposicione el reloj.
    private var stallReported = false

    /// Posición vigente.
    var progress: PlaybackProgress { PlaybackProgress(elapsed: elapsed, duration: duration) }

    // MARK: - Transiciones

    /// Pista nueva cargada en el motor.
    func load(duration: TimeInterval, startingAt elapsed: TimeInterval, at now: CFTimeInterval) {
        self.duration = duration.isFinite && duration > 0 ? duration : 0
        seek(to: elapsed, at: now)
    }

    /// Salto explícito de posición: un `seek` del usuario o una reprogramación del motor.
    /// Limpia el fin de pista y el atasco, porque a partir de aquí hay audio nuevo esperando.
    func seek(to time: TimeInterval, at now: CFTimeInterval) {
        elapsed = PlaybackProgress(elapsed: time, duration: duration).elapsed
        hasReachedEnd = false
        stallReported = false
        lastAdvanceAt = now
    }

    /// Alinea la posición con la que reporta el motor, sin tocar las marcas de fin ni de
    /// atasco. Para leer la posición en una transición (pausar, informar a la pantalla de
    /// bloqueo), no para saltar a otro punto de la pista.
    func align(to time: TimeInterval) {
        elapsed = PlaybackProgress(elapsed: time, duration: duration).elapsed
    }

    /// Vuelve a sonar tras una pausa. Reinicia la vigilancia de atasco para que el tiempo
    /// que estuvo pausado no cuente como motor parado.
    func resumed(at now: CFTimeInterval) {
        stallReported = false
        lastAdvanceAt = now
    }

    /// La pista terminó. Deja la posición exactamente en el final, que es lo que la UI y la
    /// pantalla de bloqueo deben mostrar.
    func markReachedEnd() {
        hasReachedEnd = true
        elapsed = duration
    }

    /// Sin pista cargada.
    func reset() {
        duration = 0
        elapsed = 0
        hasReachedEnd = false
        stallReported = false
        lastAdvanceAt = 0
    }

    // MARK: - Tick

    /// Evalúa un tick mientras la pista suena.
    ///
    /// No muta las marcas de fin ni emite nada: solo concluye. Quien lo llama decide qué
    /// hacer y, si procede, cierra la pista con `markReachedEnd()`. Así el tick se puede
    /// repetir sin efectos acumulados.
    ///
    /// - Parameters:
    ///   - rawPosition: posición **cruda** del motor, sin acotar, o `nil` si no la reporta.
    ///   - now: instante actual de un reloj monótono (`CACurrentMediaTime()`).
    func tick(rawPosition: TimeInterval?, at now: CFTimeInterval) -> PlaybackClockTick {
        // La posición del motor se fue más allá del final del archivo: el nodo está
        // renderizando silencio y la canción ya terminó, llegara o no su aviso.
        if let rawPosition, duration > 0, rawPosition >= duration + Self.endOfTrackTolerance {
            return .reachedEnd(PlaybackProgress(elapsed: duration, duration: duration))
        }

        guard let rawPosition, rawPosition > elapsed + Self.advanceEpsilon else {
            // El motor no entregó nada nuevo. Un tick suelto así es normal (el reloj de
            // render avanza a saltos de buffer); sostenido en el tiempo significa que se paró.
            if !stallReported, now - lastAdvanceAt >= Self.stallTimeout {
                stallReported = true
                return .stalled(progress)
            }
            return .progress(progress)
        }

        elapsed = PlaybackProgress(elapsed: rawPosition, duration: duration).elapsed
        lastAdvanceAt = now
        stallReported = false
        return .progress(progress)
    }
}
