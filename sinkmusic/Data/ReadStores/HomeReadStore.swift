//
//  HomeReadStore.swift
//  sinkmusic
//

import Foundation
import SwiftData

/// Implementación reactiva de `HomeReadStoreProtocol`.
/// Delega los reads a los UseCases existentes (no duplica lógica de negocio) y
/// añade la señal de `changes()` observando `ModelContext.didSave`.
@MainActor
final class HomeReadStore: HomeReadStoreProtocol {

    private let libraryUseCases: LibraryUseCases
    private let playlistUseCases: PlaylistUseCases
    private let observer: ModelContextChangeObserver

    init(libraryUseCases: LibraryUseCases, playlistUseCases: PlaylistUseCases, modelContext: ModelContext) {
        self.libraryUseCases = libraryUseCases
        self.playlistUseCases = playlistUseCases
        self.observer = ModelContextChangeObserver(
            modelContext: modelContext,
            relevantEntityNames: ["SongDTO", "PlaylistDTO"]
        )
    }

    func playlists() async throws -> [Playlist] {
        try await playlistUseCases.getAllPlaylists()
    }

    func mostPlayedPlaylists(limit: Int) async throws -> [Playlist] {
        try await playlistUseCases.getMostPlayedPlaylists(limit: limit)
    }

    func recentlyPlayedSongs(limit: Int) async throws -> [Song] {
        try await libraryUseCases.getRecentlyPlayedSongs(limit: limit)
    }

    func mostPlayedSongs(limit: Int) async throws -> [Song] {
        try await libraryUseCases.getMostPlayedSongs(limit: limit)
    }

    func downloadedSongs() async throws -> [Song] {
        try await libraryUseCases.getDownloadedSongs()
    }

    func changes() -> AsyncStream<Void> {
        observer.stream()
    }
}
