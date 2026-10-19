//
//  PlaybackQueue.swift
//  sinkmusic
//
//  Domain Layer - Entity
//

import Foundation

/// Qué hacer cuando una canción termina por sí sola.
enum PlaybackQueueOutcome: Equatable, Sendable {

    /// Reproducir esta canción a continuación.
    case play(songID: UUID)

    /// Final de la cola sin repetición: detener la reproducción.
    case stop

    /// La cola no puede decidir —está vacía, o la canción que terminó no está en ella—.
    /// Se deja todo como está.
    case idle
}

/// La cola de reproducción: qué suena después.
///
/// Es un value type puro, sin dependencias de UI ni del motor de audio. Antes el algoritmo
/// —orden, aleatorio, repetición, final de cola— vivía dentro de `PlayerViewModel`, que es
/// capa de presentación; es lógica de negocio y aquí se puede probar sin levantar nada.
///
/// La distinción que estructura el tipo: **avanzar porque el usuario lo pide** y **avanzar
/// porque la canción terminó** no son lo mismo. Pulsar "siguiente" en la última canción da
/// la vuelta al principio siempre; que termine sola en la última solo continúa si hay
/// repetición activada. Por eso son dos operaciones distintas, `next(after:)` y
/// `advance(after:)`, y no una con un flag.
struct PlaybackQueue: Equatable, Sendable {

    /// Canciones de la cola, en orden. Solo descargadas: quien la construye ya filtra.
    private(set) var songIDs: [UUID] = []

    var isShuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off

    var isEmpty: Bool { songIDs.isEmpty }

    init(songIDs: [UUID] = [], isShuffleEnabled: Bool = false, repeatMode: RepeatMode = .off) {
        self.songIDs = songIDs
        self.isShuffleEnabled = isShuffleEnabled
        self.repeatMode = repeatMode
    }

    /// Sustituye el contenido conservando los modos de aleatorio y repetición, que son
    /// preferencia del usuario y no de la cola concreta.
    mutating func replace(with songIDs: [UUID]) {
        self.songIDs = songIDs
    }

    // MARK: - Avance por acción del usuario

    /// Siguiente canción cuando el usuario pulsa "siguiente".
    ///
    /// Siempre avanza: en la última da la vuelta al principio, haya o no repetición. El
    /// modo de repetición describe qué pasa al *terminar* una canción, no qué pasa cuando
    /// alguien pide explícitamente otra.
    ///
    /// - Parameter pickRandom: cómo elegir en modo aleatorio. Inyectable para poder
    ///   probarlo de forma determinista; por defecto, al azar.
    func next(
        after songID: UUID,
        pickRandom: ([UUID]) -> UUID? = { $0.randomElement() }
    ) -> UUID? {
        guard !songIDs.isEmpty else { return nil }

        if isShuffleEnabled {
            return pickRandom(songIDs.filter { $0 != songID }) ?? songIDs.first
        }

        guard let index = songIDs.firstIndex(of: songID) else { return nil }
        return songIDs[(index + 1) % songIDs.count]
    }

    /// Canción anterior cuando el usuario pulsa "anterior". Simétrica de `next(after:)`.
    func previous(
        before songID: UUID,
        pickRandom: ([UUID]) -> UUID? = { $0.randomElement() }
    ) -> UUID? {
        guard !songIDs.isEmpty else { return nil }

        if isShuffleEnabled {
            return pickRandom(songIDs.filter { $0 != songID }) ?? songIDs.first
        }

        guard let index = songIDs.firstIndex(of: songID) else { return nil }
        return songIDs[(index - 1 + songIDs.count) % songIDs.count]
    }

    // MARK: - Avance porque la canción terminó

    /// Qué hacer cuando `finishedSongID` llegó a su final por sí sola.
    ///
    /// Aquí sí manda `repeatMode`: sin repetición, llegar al final de la cola detiene la
    /// reproducción en vez de volver al principio.
    func advance(
        after finishedSongID: UUID,
        pickRandom: ([UUID]) -> UUID? = { $0.randomElement() }
    ) -> PlaybackQueueOutcome {
        guard !songIDs.isEmpty else { return .idle }

        switch repeatMode {
        case .repeatOne:
            return .play(songID: finishedSongID)

        case .repeatAll:
            return outcome(next(after: finishedSongID, pickRandom: pickRandom))

        case .off:
            guard let index = songIDs.firstIndex(of: finishedSongID) else { return .idle }

            // En aleatorio no hay "última": siempre queda algo por sonar.
            guard isShuffleEnabled || index < songIDs.count - 1 else { return .stop }
            return outcome(next(after: finishedSongID, pickRandom: pickRandom))
        }
    }

    private func outcome(_ songID: UUID?) -> PlaybackQueueOutcome {
        songID.map { .play(songID: $0) } ?? .idle
    }
}
