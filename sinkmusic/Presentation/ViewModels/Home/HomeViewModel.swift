//
//  HomeViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + read-side reactivo (HomeReadStore)
//  SOLID: Single Responsibility - Maneja UI de la pantalla principal
//

import Foundation
import SwiftUI
import os

/// ViewModel responsable de la UI de la pantalla principal
/// Muestra playlists, canciones recientes y recomendaciones
/// Es puramente de lectura: la reactividad viene de `HomeReadStoreProtocol`,
/// que reacciona a cambios de SwiftData sin pasar por el EventBus global.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var playlists: [PlaylistUI] = []
    var mostPlayedPlaylists: [PlaylistUI] = []
    var recentSongs: [SongUI] = []
    var mostPlayedSongs: [SongUI] = []
    var downloadedSongs: [SongUI] = []

    var libraryStats: LibraryStats?
    var isLoading: Bool = false

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Home")

    // MARK: - Dependencies

    private let readStore: HomeReadStoreProtocol

    // MARK: - Tasks

    /// Task para observar cambios reactivos del ReadStore
    @ObservationIgnored
    private var changesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(readStore: HomeReadStoreProtocol) {
        self.readStore = readStore
        changesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in readStore.changes() {
                guard !Task.isCancelled else { break }
                // Recarga en segundo plano, sin isLoading: esto se dispara con cambios
                // menores como incrementar playCount al reproducir una canción, y no debe
                // reemplazar el contenido visible por un spinner (ver reloadAllSections()).
                await self.reloadAllSections()
            }
        }
        Task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    /// Carga todos los datos de la pantalla principal (con spinner — carga inicial / refresh explícito)
    func loadData() async {
        isLoading = true
        await reloadAllSections()
        isLoading = false
    }

    /// Recarga las secciones de Home sin tocar `isLoading`.
    /// Usado por la reactividad del ReadStore: los datos ya están en pantalla, así que
    /// reemplazarlos por un spinner en cada cambio se sentiría como una recarga completa.
    private func reloadAllSections() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPlaylists() }
            group.addTask { await self.loadMostPlayedPlaylists() }
            group.addTask { await self.loadRecentSongs() }
            group.addTask { await self.loadMostPlayedSongs() }
            group.addTask { await self.loadDownloadedSongs() }
        }
    }

    /// Carga playlists
    private func loadPlaylists() async {
        await loadAndAssign(
            fetch: { try await readStore.playlists() },
            map: { $0.map(PlaylistMapper.toUI) },
            assign: { playlists = $0 },
            onError: { [self] in logger.error("Error al cargar playlists: \($0)") }
        )
    }

    /// Carga playlists más escuchadas (ordenadas por reproducciones totales), máximo 10.
    private func loadMostPlayedPlaylists() async {
        await loadAndAssign(
            fetch: { try await readStore.mostPlayedPlaylists(limit: 10) },
            map: { $0.map(PlaylistMapper.toUI) },
            assign: { mostPlayedPlaylists = $0 },
            onError: { [self] in logger.error("Error al cargar playlists más escuchadas: \($0)") }
        )
    }

    /// Carga canciones recientes (via ReadStore)
    private func loadRecentSongs() async {
        await loadAndAssign(
            fetch: { try await readStore.recentlyPlayedSongs(limit: 10) },
            map: { $0.map(SongMapper.toUI) },
            assign: { recentSongs = $0 },
            onError: { [self] in logger.error("Error al cargar canciones recientes: \($0)") }
        )
    }

    /// Carga canciones más reproducidas (via ReadStore)
    private func loadMostPlayedSongs() async {
        await loadAndAssign(
            fetch: { try await readStore.mostPlayedSongs(limit: 10) },
            map: { $0.map(SongMapper.toUI) },
            assign: { mostPlayedSongs = $0 },
            onError: { [self] in logger.error("Error al cargar canciones más reproducidas: \($0)") }
        )
    }

    /// Carga canciones descargadas (via ReadStore)
    private func loadDownloadedSongs() async {
        await loadAndAssign(
            fetch: { try await readStore.downloadedSongs() },
            map: { $0.map(SongMapper.toUI) },
            assign: { downloadedSongs = $0 },
            onError: { [self] in logger.error("Error al cargar canciones descargadas: \($0)") }
        )
    }

    // MARK: - Quick Actions

    /// Recarga todos los datos
    func refresh() async {
        await loadData()
    }

    // MARK: - Helpers

    /// Indica si hay contenido para mostrar
    var hasContent: Bool {
        !playlists.isEmpty || !mostPlayedPlaylists.isEmpty || !recentSongs.isEmpty || !mostPlayedSongs.isEmpty
    }

    /// Cuenta total de canciones
    var totalSongsCount: Int {
        downloadedSongs.count
    }

    // MARK: - Cleanup

    deinit {
        changesTask?.cancel()
    }
}
