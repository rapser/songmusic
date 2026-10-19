//
//  LibraryAggregationUseCases.swift
//  sinkmusic
//
//  Domain Layer - UseCase
//

import Foundation

/// Agrupaciones de la biblioteca: artistas, álbumes y cuántas canciones tiene cada uno.
///
/// Salían de `SearchUseCases`, pero no son búsqueda: quien las consume es el carrusel de
/// Inicio y los selectores de filtro, que las piden sin que nadie haya escrito nada. Estaban
/// ahí porque la pantalla de Búsqueda fue la primera en necesitarlas.
@MainActor
final class LibraryAggregationUseCases: Sendable {

    private let songRepository: SongRepositoryProtocol

    init(songRepository: SongRepositoryProtocol) {
        self.songRepository = songRepository
    }

    // MARK: - Aggregations
    //
    // Excepción aceptada: los 4 métodos de esta sección usan `getAll()` porque son
    // agregaciones (distinct/conteo) sobre *todas* las canciones — SwiftData no soporta
    // GROUP BY/DISTINCT a nivel de FetchDescriptor, así que no hay query targeted posible
    // sin ejecutar SQL crudo (fuera de alcance).

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

extension SearchUseCases: Sendable {
}
