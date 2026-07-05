//
//  SearchViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + read-side reactivo (SearchReadStore)
//  SOLID: Single Responsibility - Maneja UI de búsqueda y filtros
//

import Foundation
import SwiftUI
import os

/// ViewModel responsable de la UI de búsqueda
/// Delega la lectura (reactiva) a `SearchReadStoreProtocol`, que reacciona a cambios
/// de SwiftData hechos desde cualquier pantalla — antes esta pantalla no reaccionaba a nada.
@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var searchQuery: String = ""
    var searchResults: [SongUI] = []
    var selectedArtist: String?
    var selectedAlbum: String?
    var downloadedOnly: Bool = false
    var sortOption: SortOption = .title
    var isSearching: Bool = false

    var artists: [String] = []
    var albums: [String] = []
    var mostPlayedSongs: [SongUI] = []
    var recentlyPlayedSongs: [SongUI] = []

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Search")

    // MARK: - Dependencies

    private let readStore: SearchReadStoreProtocol

    // MARK: - Tasks

    /// Task para observar cambios reactivos del ReadStore
    @ObservationIgnored
    private var changesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(readStore: SearchReadStoreProtocol) {
        self.readStore = readStore
        changesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in readStore.changes() {
                guard !Task.isCancelled else { break }
                // Re-ejecuta la última búsqueda activa para reflejar cambios hechos en otra
                // pantalla, sin isSearching: esto se dispara con cambios menores como
                // incrementar playCount al reproducir una canción, y no debe reemplazar los
                // resultados visibles por un spinner (ver performSearch()).
                await self.performSearch()
                await self.loadAggregations()
                await self.loadRecommendations()
            }
        }
        Task {
            await loadAggregations()
            await loadRecommendations()
        }
    }

    // MARK: - Search Operations

    /// Realiza búsqueda con el query actual (con spinner — acción explícita del usuario)
    func search() async {
        isSearching = true
        await performSearch()
        isSearching = false
    }

    /// Ejecuta la búsqueda actual sin tocar `isSearching`.
    /// Usado por la reactividad del ReadStore: los resultados ya están en pantalla, así que
    /// reemplazarlos por un spinner en cada cambio se sentiría como una recarga completa.
    private func performSearch() async {
        do {
            let entities = try await readStore.search(
                query: searchQuery.isEmpty ? nil : searchQuery,
                artist: selectedArtist,
                album: selectedAlbum,
                downloadedOnly: downloadedOnly,
                sortBy: sortOption
            )
            searchResults = entities.map { SongMapper.toUI($0) }
        } catch {
            logger.error("Error en búsqueda: \(error)")
            searchResults = []
        }
    }

    /// Busca canciones por texto simple
    func searchSongs(query: String) async {
        searchQuery = query
        await search()
    }

    /// Filtra por artista
    func filterByArtist(_ artist: String) async {
        selectedArtist = artist
        selectedAlbum = nil
        await search()
    }

    /// Filtra por álbum
    func filterByAlbum(_ album: String) async {
        selectedAlbum = album
        selectedArtist = nil
        await search()
    }

    /// Limpia todos los filtros
    func clearFilters() async {
        searchQuery = ""
        selectedArtist = nil
        selectedAlbum = nil
        downloadedOnly = false
        await search()
    }

    /// Cambia el filtro de descargadas
    func toggleDownloadedOnly() async {
        downloadedOnly.toggle()
        await search()
    }

    /// Cambia la opción de ordenamiento
    func changeSortOption(_ option: SortOption) async {
        sortOption = option
        await search()
    }

    // MARK: - Quick Filters

    /// Obtiene canciones descargadas
    func getDownloadedSongs() async {
        do {
            let entities = try await readStore.downloadedSongs()
            searchResults = entities.map { SongMapper.toUI($0) }
        } catch {
            logger.error("Error al obtener descargadas: \(error)")
        }
    }

    /// Obtiene canciones no descargadas
    func getNotDownloadedSongs() async {
        do {
            let entities = try await readStore.notDownloadedSongs()
            searchResults = entities.map { SongMapper.toUI($0) }
        } catch {
            logger.error("Error al obtener no descargadas: \(error)")
        }
    }

    // MARK: - Aggregations

    /// Carga artistas y álbumes únicos
    func loadAggregations() async {
        do {
            artists = try await readStore.allArtists()
            albums = try await readStore.allAlbums()
        } catch {
            logger.error("Error al cargar agregaciones: \(error)")
        }
    }

    // MARK: - Recommendations

    /// Carga canciones más reproducidas y recientes
    func loadRecommendations() async {
        do {
            let mostPlayed = try await readStore.mostPlayedSongs(limit: 10)
            let recentlyPlayed = try await readStore.recentlyPlayedSongs(limit: 10)

            mostPlayedSongs = mostPlayed.map { SongMapper.toUI($0) }
            recentlyPlayedSongs = recentlyPlayed.map { SongMapper.toUI($0) }
        } catch {
            logger.error("Error al cargar recomendaciones: \(error)")
        }
    }

    // MARK: - Cleanup

    deinit {
        changesTask?.cancel()
    }
}
