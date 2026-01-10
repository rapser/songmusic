//
//  SearchViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI de búsqueda y filtros
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de búsqueda
/// Delega lógica de negocio a SearchUseCases
@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var searchQuery: String = ""
    var searchResults: [SongUIModel] = []
    var selectedArtist: String?
    var selectedAlbum: String?
    var downloadedOnly: Bool = false
    var sortOption: SortOption = .title
    var isSearching: Bool = false

    var artists: [String] = []
    var albums: [String] = []
    var mostPlayedSongs: [SongUIModel] = []
    var recentlyPlayedSongs: [SongUIModel] = []

    // MARK: - Dependencies

    private let searchUseCases: SearchUseCases

    // MARK: - Initialization

    init(searchUseCases: SearchUseCases) {
        self.searchUseCases = searchUseCases
        Task {
            await loadAggregations()
            await loadRecommendations()
        }
    }

    // MARK: - Search Operations

    /// Realiza búsqueda con el query actual
    func search() async {
        isSearching = true

        do {
            let entities: [SongEntity]
            if searchQuery.isEmpty && selectedArtist == nil && selectedAlbum == nil {
                // Sin filtros: mostrar todas las canciones
                entities = try await searchUseCases.advancedSearch(
                    query: nil,
                    artist: nil,
                    album: nil,
                    downloadedOnly: downloadedOnly,
                    sortBy: sortOption
                )
            } else {
                // Búsqueda avanzada con filtros
                entities = try await searchUseCases.advancedSearch(
                    query: searchQuery.isEmpty ? nil : searchQuery,
                    artist: selectedArtist,
                    album: selectedAlbum,
                    downloadedOnly: downloadedOnly,
                    sortBy: sortOption
                )
            }
            searchResults = entities.map { SongMapper.toUIModel($0) }
        } catch {
            print("❌ Error en búsqueda: \(error)")
            searchResults = []
        }

        isSearching = false
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
            let entities = try await searchUseCases.getDownloadedSongs()
            searchResults = entities.map { SongMapper.toUIModel($0) }
        } catch {
            print("❌ Error al obtener descargadas: \(error)")
        }
    }

    /// Obtiene canciones no descargadas
    func getNotDownloadedSongs() async {
        do {
            let entities = try await searchUseCases.getNotDownloadedSongs()
            searchResults = entities.map { SongMapper.toUIModel($0) }
        } catch {
            print("❌ Error al obtener no descargadas: \(error)")
        }
    }

    // MARK: - Aggregations

    /// Carga artistas y álbumes únicos
    func loadAggregations() async {
        do {
            artists = try await searchUseCases.getAllArtists()
            albums = try await searchUseCases.getAllAlbums()
        } catch {
            print("❌ Error al cargar agregaciones: \(error)")
        }
    }

    // MARK: - Recommendations

    /// Carga canciones más reproducidas y recientes
    func loadRecommendations() async {
        do {
            let mostPlayed = try await searchUseCases.getMostPlayedSongs(limit: 10)
            let recentlyPlayed = try await searchUseCases.getRecentlyPlayedSongs(limit: 10)

            mostPlayedSongs = mostPlayed.map { SongMapper.toUIModel($0) }
            recentlyPlayedSongs = recentlyPlayed.map { SongMapper.toUIModel($0) }
        } catch {
            print("❌ Error al cargar recomendaciones: \(error)")
        }
    }
}
