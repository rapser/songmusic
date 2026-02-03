//
//  HomeViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Maneja UI de la pantalla principal
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de la pantalla principal
/// Muestra playlists, canciones recientes y recomendaciones
/// Usa EventBus con AsyncStream para reactividad moderna
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var playlists: [PlaylistUI] = []
    var recentSongs: [SongUI] = []
    var mostPlayedSongs: [SongUI] = []
    var downloadedSongs: [SongUI] = []

    var libraryStats: LibraryStats?
    var isLoading: Bool = false

    // MARK: - Dependencies

    private let playlistUseCases: PlaylistUseCases
    private let libraryUseCases: LibraryUseCases
    private let eventBus: EventBusProtocol

    // MARK: - Tasks

    /// Task para observación de eventos (nonisolated para acceso en deinit)
    nonisolated(unsafe) private var dataEventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        playlistUseCases: PlaylistUseCases,
        libraryUseCases: LibraryUseCases,
        eventBus: EventBusProtocol
    ) {
        self.playlistUseCases = playlistUseCases
        self.libraryUseCases = libraryUseCases
        self.eventBus = eventBus
        startObservingEvents()
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
            let entities = try await playlistUseCases.getAllPlaylists()
            playlists = entities.map { PlaylistMapper.toUI($0) }
        } catch {
            print("❌ Error al cargar playlists: \(error)")
        }
    }

    /// Carga canciones recientes (via UseCase)
    private func loadRecentSongs() async {
        do {
            let entities = try await libraryUseCases.getRecentlyPlayedSongs(limit: 10)
            recentSongs = entities.map { SongMapper.toUI($0) }
        } catch {
            print("❌ Error al cargar canciones recientes: \(error)")
        }
    }

    /// Carga canciones más reproducidas (via UseCase)
    private func loadMostPlayedSongs() async {
        do {
            let entities = try await libraryUseCases.getMostPlayedSongs(limit: 10)
            mostPlayedSongs = entities.map { SongMapper.toUI($0) }
        } catch {
            print("❌ Error al cargar canciones más reproducidas: \(error)")
        }
    }

    /// Carga canciones descargadas (via UseCase)
    private func loadDownloadedSongs() async {
        do {
            let entities = try await libraryUseCases.getDownloadedSongs()
            downloadedSongs = entities.map { SongMapper.toUI($0) }
        } catch {
            print("❌ Error al cargar canciones descargadas: \(error)")
        }
    }

    // MARK: - Quick Actions

    /// Recarga todos los datos
    func refresh() async {
        await loadData()
    }

    // MARK: - Event Observation (EventBus + AsyncStream)

    private func startObservingEvents() {
        dataEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.eventBus.dataEvents() {
                guard !Task.isCancelled else { break }
                await self.handleDataEvent(event)
            }
        }
    }

    private func handleDataEvent(_ event: DataChangeEvent) async {
        switch event {
        case .songsUpdated:
            await loadRecentSongs()
            await loadMostPlayedSongs()
            await loadDownloadedSongs()

        case .playlistsUpdated:
            await loadPlaylists()

        case .songDownloaded:
            await loadDownloadedSongs()

        case .songDeleted:
            await loadRecentSongs()
            await loadMostPlayedSongs()
            await loadDownloadedSongs()

        case .credentialsChanged:
            // Recargar todo cuando cambian las credenciales
            await loadData()

        case .error:
            // Handle error if needed
            break
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

    // MARK: - Cleanup

    deinit {
        dataEventTask?.cancel()
    }
}
