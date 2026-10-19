//
//  PlaybackProgress.swift
//  sinkmusic
//
//  Domain Layer - Entity
//

import Foundation

/// Posición de reproducción: **el único valor de tiempo que circula por la app**.
///
/// La produce siempre el `PlaybackClock`, que es quien conoce la posición real del motor
/// de audio y la duración real del archivo. Ninguna otra capa calcula tiempos: la UI, la
/// pantalla de bloqueo, la Live Activity y la persistencia leen todas este mismo valor.
/// Tener una sola fuente es lo que impide que el reproductor de la app y el nativo se
/// separen.
///
/// Es imposible construir una posición inválida: el inicializador acota `elapsed` al rango
/// `0...duration` y descarta NaN/infinitos. Eso convierte "el tiempo nunca pasa del final
/// de la canción" en una invariante del tipo, no en una comprobación que alguien pueda
/// olvidarse de repetir en cada sitio que lo consume.
struct PlaybackProgress: Equatable, Sendable {

    /// Tiempo transcurrido, garantizado dentro de `0...duration`.
    let elapsed: TimeInterval

    /// Duración de la pista. `0` significa "aún no se conoce".
    let duration: TimeInterval

    static let zero = PlaybackProgress(elapsed: 0, duration: 0)

    init(elapsed: TimeInterval, duration: TimeInterval) {
        let safeDuration = duration.isFinite && duration > 0 ? duration : 0
        let safeElapsed = elapsed.isFinite ? max(0, elapsed) : 0

        self.duration = safeDuration
        self.elapsed = safeDuration > 0 ? min(safeElapsed, safeDuration) : safeElapsed
    }

    /// Tiempo restante hasta el final de la pista.
    var remaining: TimeInterval { max(0, duration - elapsed) }

    /// Avance en `0...1` para barras de progreso. `0` mientras no se conozca la duración.
    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    /// La posición está en el final de la pista.
    var isAtEnd: Bool { duration > 0 && elapsed >= duration }
}
