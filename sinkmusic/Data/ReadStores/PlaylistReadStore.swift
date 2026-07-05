//
//  PlaylistReadStore.swift
//  sinkmusic
//

import Foundation
import SwiftData

/// Implementación reactiva de `PlaylistReadStoreProtocol`.
/// Delega los reads a `PlaylistUseCases` y añade la señal de `changes()`
/// observando `ModelContext.didSave` filtrado a `SongDTO`/`PlaylistDTO`
/// (una playlist muestra canciones, así que un cambio en cualquiera de las dos importa).
@MainActor
final class PlaylistReadStore: PlaylistReadStoreProtocol {

    private let playlistUseCases: PlaylistUseCases
    private let observer: ModelContextChangeObserver

    init(playlistUseCases: PlaylistUseCases, modelContext: ModelContext) {
        self.playlistUseCases = playlistUseCases
        self.observer = ModelContextChangeObserver(
            modelContext: modelContext,
            relevantEntityNames: ["SongDTO", "PlaylistDTO"]
        )
    }

    func allPlaylists() async throws -> [Playlist] {
        try await playlistUseCases.getAllPlaylists()
    }

    func songs(inPlaylist id: UUID) async throws -> [Song] {
        try await playlistUseCases.getSongsInPlaylist(id)
    }

    func stats(forPlaylist id: UUID) async throws -> PlaylistStats {
        try await playlistUseCases.getPlaylistStats(id)
    }

    func changes() -> AsyncStream<Void> {
        observer.stream()
    }
}
