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
    private let homeLayoutUseCases: HomePlaylistLayoutUseCases
    private let observer: ModelContextChangeObserver

    init(
        libraryUseCases: LibraryUseCases,
        playlistUseCases: PlaylistUseCases,
        homeLayoutUseCases: HomePlaylistLayoutUseCases,
        modelContext: ModelContext
    ) {
        self.libraryUseCases = libraryUseCases
        self.playlistUseCases = playlistUseCases
        self.homeLayoutUseCases = homeLayoutUseCases
        self.observer = ModelContextChangeObserver(
            modelContext: modelContext,
            // `SongPlayStatsDTO` porque Inicio es la única pantalla que muestra algo
            // derivado de las reproducciones ("lo que más escuchas", "recientes"). Antes
            // ese aviso llegaba por `SongDTO`, y de paso despertaba a las otras tres.
            relevantEntityNames: ["SongDTO", "PlaylistDTO", "SongPlayStatsDTO"]
        )
    }

    func playlists() async throws -> [Playlist] {
        try await homeLayoutUseCases.getHomePlaylistLayout().shown
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

    func setReactiveReloads(suspended: Bool) {
        suspended ? observer.suspend() : observer.resume()
    }
}
