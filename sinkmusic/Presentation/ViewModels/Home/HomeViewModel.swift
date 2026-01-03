//
//  HomeViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI de la pantalla principal
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de la pantalla principal
/// Muestra playlists, canciones recientes y recomendaciones
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State

    var playlists: [PlaylistEntity] = []
    var recentSongs: [SongEntity] = []
    var mostPlayedSongs: [SongEntity] = []
    var downloadedSongs: [SongEntity] = []

    var libraryStats: LibraryStats?
    var isLoading: Bool = false

    // MARK: - Dependencies

    private let playlistUseCases: PlaylistUseCases
    private let songRepository: SongRepositoryProtocol

    // MARK: - Initialization

    init(
        playlistUseCases: PlaylistUseCases,
        songRepository: SongRepositoryProtocol
    ) {
        self.playlistUseCases = playlistUseCases
        self.songRepository = songRepository
        setupObservers()
        Task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    /// Carga todos los datos de la pantalla principal
    func loadData() async {
        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPlaylists() }
            group.addTask { await self.loadRecentSongs() }
            group.addTask { await self.loadMostPlayedSongs() }
            group.addTask { await self.loadDownloadedSongs() }
        }

        isLoading = false
    }

    /// Carga playlists
    private func loadPlaylists() async {
        do {
            playlists = try await playlistUseCases.getAllPlaylists()
        } catch {
            print("❌ Error al cargar playlists: \(error)")
        }
    }

    /// Carga canciones recientes
    private func loadRecentSongs() async {
        do {
            let allSongs = try await songRepository.getAll()
            recentSongs = allSongs
                .filter { $0.lastPlayedAt != nil }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(10)
                .map { $0 }
        } catch {
            print("❌ Error al cargar canciones recientes: \(error)")
        }
    }

    /// Carga canciones más reproducidas
    private func loadMostPlayedSongs() async {
        do {
            let allSongs = try await songRepository.getAll()
            mostPlayedSongs = allSongs
                .filter { $0.playCount > 0 }
                .sorted { $0.playCount > $1.playCount }
                .prefix(10)
                .map { $0 }
        } catch {
            print("❌ Error al cargar canciones más reproducidas: \(error)")
        }
    }

    /// Carga canciones descargadas
    private func loadDownloadedSongs() async {
        do {
            let allSongs = try await songRepository.getAll()
            downloadedSongs = allSongs.filter { $0.isDownloaded }
        } catch {
            print("❌ Error al cargar canciones descargadas: \(error)")
        }
    }

    // MARK: - Quick Actions

    /// Recarga todos los datos
    func refresh() async {
        await loadData()
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observar cambios en playlists
        playlistUseCases.observePlaylistChanges { [weak self] updatedPlaylists in
            guard let self = self else { return }
            self.playlists = updatedPlaylists
        }

        // Observar cambios en canciones
        songRepository.observeChanges { [weak self] updatedSongs in
            guard let self = self else { return }
            Task {
                await self.loadRecentSongs()
                await self.loadMostPlayedSongs()
                await self.loadDownloadedSongs()
            }
        }
    }

    // MARK: - Helpers

    /// Indica si hay contenido para mostrar
    var hasContent: Bool {
        !playlists.isEmpty || !recentSongs.isEmpty || !mostPlayedSongs.isEmpty
    }

    /// Cuenta total de canciones
    var totalSongsCount: Int {
        downloadedSongs.count
    }
}
