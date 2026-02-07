//
//  SearchUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para búsqueda de canciones
/// Proporciona filtrado y búsqueda en la biblioteca
@MainActor
final class SearchUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol

    // MARK: - Initialization

    init(songRepository: SongRepositoryProtocol) {
        self.songRepository = songRepository
    }

    // MARK: - Search Operations

    /// Busca canciones por query de texto
    func searchSongs(query: String) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()

        guard !query.isEmpty else {
            return allSongs
        }

        let lowercaseQuery = query.lowercased()

        return allSongs.filter { song in
            song.title.lowercased().contains(lowercaseQuery) ||
            song.artist.lowercased().contains(lowercaseQuery) ||
            song.album?.lowercased().contains(lowercaseQuery) ?? false
        }
    }

    /// Filtra canciones por artista
    func filterByArtist(_ artist: String) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs.filter { $0.artist == artist }
    }

    /// Filtra canciones por álbum
    func filterByAlbum(_ album: String) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs.filter { $0.album == album }
    }

    /// Filtra canciones descargadas
    func getDownloadedSongs() async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs.filter { $0.isDownloaded }
    }

    /// Filtra canciones no descargadas
    func getNotDownloadedSongs() async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs.filter { !$0.isDownloaded }
    }

    /// Obtiene canciones más reproducidas
    func getMostPlayedSongs(limit: Int = 20) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs
            .filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }
            .prefix(limit)
            .map { $0 }
    }

    /// Obtiene canciones reproducidas recientemente
    func getRecentlyPlayedSongs(limit: Int = 20) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Advanced Search

    /// Búsqueda avanzada con múltiples filtros
    func advancedSearch(
        query: String?,
        artist: String?,
        album: String?,
        downloadedOnly: Bool = false,
        sortBy: SortOption = .title
    ) async throws -> [Song] {
        var results = try await songRepository.getAll()

        // Aplicar filtro de texto
        if let query = query, !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            results = results.filter { song in
                song.title.lowercased().contains(lowercaseQuery) ||
                song.artist.lowercased().contains(lowercaseQuery) ||
                song.album?.lowercased().contains(lowercaseQuery) ?? false
            }
        }

        // Aplicar filtro de artista
        if let artist = artist, !artist.isEmpty {
            results = results.filter { $0.artist == artist }
        }

        // Aplicar filtro de álbum
        if let album = album, !album.isEmpty {
            results = results.filter { $0.album == album }
        }

        // Aplicar filtro de descargadas
        if downloadedOnly {
            results = results.filter { $0.isDownloaded }
        }

        // Aplicar ordenamiento
        return sortSongs(results, by: sortBy)
    }

    // MARK: - Sorting

    /// Ordena canciones según la opción especificada
    func sortSongs(_ songs: [Song], by option: SortOption) -> [Song] {
        switch option {
        case .title:
            return songs.sorted { $0.title < $1.title }
        case .artist:
            return songs.sorted { $0.artist < $1.artist }
        case .album:
            return songs.sorted {
                ($0.album ?? "") < ($1.album ?? "")
            }
        case .playCount:
            return songs.sorted { $0.playCount > $1.playCount }
        case .duration:
            return songs.sorted {
                ($0.duration ?? 0) > ($1.duration ?? 0)
            }
        case .recentlyPlayed:
            return songs.sorted {
                ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast)
            }
        }
    }

    // MARK: - Aggregations

    /// Obtiene lista única de artistas
    func getAllArtists() async throws -> [String] {
        let allSongs = try await songRepository.getAll()
        let artists = Set(allSongs.map { $0.artist })
        return artists.sorted()
    }

    /// Obtiene lista única de álbumes
    func getAllAlbums() async throws -> [String] {
        let allSongs = try await songRepository.getAll()
        let albums = Set(allSongs.compactMap { $0.album })
        return albums.sorted()
    }

    /// Obtiene cantidad de canciones por artista
    func getSongCountByArtist() async throws -> [String: Int] {
        let allSongs = try await songRepository.getAll()
        var counts: [String: Int] = [:]

        for song in allSongs {
            counts[song.artist, default: 0] += 1
        }

        return counts
    }

    /// Obtiene cantidad de canciones por álbum
    func getSongCountByAlbum() async throws -> [String: Int] {
        let allSongs = try await songRepository.getAll()
        var counts: [String: Int] = [:]

        for song in allSongs {
            if let album = song.album {
                counts[album, default: 0] += 1
            }
        }

        return counts
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable, Sendable {
    case title = "Título"
    case artist = "Artista"
    case album = "Álbum"
    case playCount = "Reproducciones"
    case duration = "Duración"
    case recentlyPlayed = "Reciente"
}

// MARK: - Sendable Conformance

extension SearchUseCases: Sendable {}
