//
//  PlaybackStateRepositoryImpl.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de estado de reproducción usando UserDefaults.
/// Persiste únicamente el ID de la última canción y el tiempo en el que se dejó
/// de escuchar, para poder restaurar el mini reproductor al volver a abrir la app.
final class PlaybackStateRepositoryImpl: PlaybackStateRepositoryProtocol {

    private enum Keys {
        static let songID = "lastPlayedSongID"
        static let time = "lastPlayedTime"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(songID: UUID, time: TimeInterval) {
        defaults.set(songID.uuidString, forKey: Keys.songID)
        defaults.set(time, forKey: Keys.time)
    }

    func load() -> (songID: UUID, time: TimeInterval)? {
        guard let idString = defaults.string(forKey: Keys.songID),
              let songID = UUID(uuidString: idString) else {
            return nil
        }
        return (songID, defaults.double(forKey: Keys.time))
    }

    func clear() {
        defaults.removeObject(forKey: Keys.songID)
        defaults.removeObject(forKey: Keys.time)
    }
}

// MARK: - Sendable Conformance

extension PlaybackStateRepositoryImpl: @unchecked Sendable {}
