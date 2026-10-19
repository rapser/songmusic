//
//  SongRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Implementación del repositorio de canciones
/// Transforma entre DTOs (Data) y Entities (Domain) usando SongMapper
@MainActor
final class SongRepositoryImpl: SongRepositoryProtocol {

    // MARK: - Properties

    private let localDataSource: SongLocalDataSource

    /// Ranking de Inicio ("Canciones que más escuchas"): contador con ventana de 7 días,
    /// persistido en su propia entidad SwiftData (`RankingWindowEntryDTO`), independiente
    /// del `playCount` histórico de la canción.
    private let rankingWindowRepository: RankingWindowRepositoryProtocol

    // MARK: - Lifecycle

    init(
        localDataSource: SongLocalDataSource,
        rankingWindowRepository: RankingWindowRepositoryProtocol
    ) {
        self.localDataSource = localDataSource
        self.rankingWindowRepository = rankingWindowRepository
    }

    // MARK: - Query Operations

    func getAll() async throws -> [Song] {
        let dtos = try localDataSource.getAll()
        return SongMapper.toDomain(dtos)
    }

    func getByID(_ id: UUID) async throws -> Song? {
        guard let dto = try localDataSource.getByID(id) else { return nil }
        return SongMapper.toDomain(dto)
    }

    func getByFileID(_ fileID: String) async throws -> Song? {
        guard let dto = try localDataSource.getByFileID(fileID) else { return nil }
        return SongMapper.toDomain(dto)
    }

    func getDownloaded() async throws -> [Song] {
        let dtos = try localDataSource.getDownloaded()
        return SongMapper.toDomain(dtos)
    }

    func getPending() async throws -> [Song] {
        let dtos = try localDataSource.getPending()
        return SongMapper.toDomain(dtos)
    }

    /// Top canciones del ranking de Inicio.
    ///
    /// Con actividad reciente manda el contador de ventana (7 días) y no el `playCount`
    /// histórico: así el listado se mantiene fresco y ninguna canción se queda fija
    /// eternamente en el puesto 1. Las ventanas caducadas ya fueron descartadas por
    /// `activeCounts()`.
    ///
    /// Cuando no queda ninguna ventana viva —una semana sin escuchar nada— se cae al
    /// `playCount` histórico en lugar de devolver una lista vacía, que es lo que dejaba
    /// la sección de Inicio en blanco. Sigue siendo un ranking de verdad, y en cuanto se
    /// reproduzca algo la ventana vuelve a mandar.
    func getTopSongs(limit: Int = 10) async throws -> [Song] {
        let counts = await rankingWindowRepository.activeCounts()

        // `getDownloaded()` excluye canciones sin descargar: al quitar una descarga sale
        // del ranking aunque conserve su ventana (se limpia sola al caducar).
        let downloaded = try localDataSource.getDownloaded()

        let ranked: [SongDTO] = counts.isEmpty
            // Nunca se reprodujo nada: la sección sí debe salir vacía, no listar la
            // biblioteca entera por orden alfabético bajo "lo que más escuchas".
            ? rank(downloaded.filter { $0.playCount > 0 }, limit: limit) { $0.playCount }
            : rank(downloaded.filter { counts[$0.id] != nil }, limit: limit) { counts[$0.id] ?? 0 }

        return SongMapper.toDomain(ranked)
    }

    /// Ordena de mayor a menor por el contador dado, desempatando por título para que el
    /// orden sea estable entre lecturas.
    private func rank(
        _ songs: [SongDTO],
        limit: Int,
        by count: (SongDTO) -> Int
    ) -> [SongDTO] {
        let sorted = songs.sorted { lhs, rhs in
            let left = count(lhs)
            let right = count(rhs)
            if left != right { return left > right }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return Array(sorted.prefix(limit))
    }

    func getRecentlyPlayed(limit: Int = 10) async throws -> [Song] {
        let dtos = try localDataSource.getRecentlyPlayed(limit: limit)
        return SongMapper.toDomain(dtos)
    }

    func search(query: String) async throws -> [Song] {
        let dtos = try localDataSource.search(query: query)
        return SongMapper.toDomain(dtos)
    }

    func searchByAlbum(query: String) async throws -> [Song] {
        let dtos = try localDataSource.searchByAlbum(query: query)
        return SongMapper.toDomain(dtos)
    }

    // MARK: - Mutation Operations

    func create(_ song: Song) async throws {
        let dto = SongMapper.toDTO(song)
        try localDataSource.create(dto)
    }

    func create(_ songs: [Song]) async throws {
        let dtos = songs.map(SongMapper.toDTO)
        try localDataSource.create(dtos)
    }

    func update(_ song: Song) async throws {
        let dto = SongMapper.toDTO(song)
        try localDataSource.update(dto)
    }

    func delete(_ id: UUID) async throws {
        try localDataSource.delete(id)
        await rankingWindowRepository.remove(songID: id)
    }

    func deleteAll() async throws {
        try localDataSource.deleteAll()
        await rankingWindowRepository.clear()
    }

    // MARK: - Specific Operations

    func incrementPlayCount(for id: UUID) async throws {
        try localDataSource.incrementPlayCount(for: id)
        // Abre o incrementa la ventana de 7 días de esta canción en el ranking de Inicio.
        await rankingWindowRepository.registerPlay(songID: id)
    }

    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) async throws {
        try localDataSource.updateDownloadStatus(for: id, isDownloaded: isDownloaded)
    }

    func updateMetadata(
        for id: UUID,
        duration: TimeInterval?,
        artworkData: Data?,
        artworkThumbnail: Data?,
        artworkMediumThumbnail: Data?,
        album: String?,
        author: String?
    ) async throws {
        try localDataSource.updateMetadata(
            for: id,
            duration: duration,
            artworkData: artworkData,
            artworkThumbnail: artworkThumbnail,
            artworkMediumThumbnail: artworkMediumThumbnail,
            album: album,
            author: author
        )
    }

}

// MARK: - Sendable Conformance

extension SongRepositoryImpl: Sendable {}
