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

    /// Reproducciones históricas (`playCount`, `lastPlayedAt`), en su propia entidad y no en
    /// la fila de la canción: ver `SongPlayStatsDTO`.
    private let playStatsDataSource: SongPlayStatsLocalDataSource

    // MARK: - Lifecycle

    init(
        localDataSource: SongLocalDataSource,
        rankingWindowRepository: RankingWindowRepositoryProtocol,
        playStatsDataSource: SongPlayStatsLocalDataSource
    ) {
        self.localDataSource = localDataSource
        self.rankingWindowRepository = rankingWindowRepository
        self.playStatsDataSource = playStatsDataSource
    }

    // MARK: - Query Operations

    func getAll() async throws -> [Song] {
        let dtos = try localDataSource.getAll()
        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
    }

    func getByID(_ id: UUID) async throws -> Song? {
        guard let dto = try localDataSource.getByID(id) else { return nil }
        return SongMapper.toDomain(dto, stats: try playStatsDataSource.stats(for: id))
    }

    func getByFileID(_ fileID: String) async throws -> Song? {
        guard let dto = try localDataSource.getByFileID(fileID) else { return nil }
        return SongMapper.toDomain(dto, stats: try playStatsDataSource.stats(for: dto.id))
    }

    func getDownloaded() async throws -> [Song] {
        let dtos = try localDataSource.getDownloaded()
        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
    }

    func getPending() async throws -> [Song] {
        let dtos = try localDataSource.getPending()
        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
    }

    /// Top canciones del ranking de Inicio.
    ///
    /// Con actividad reciente manda el contador de ventana y no el `playCount` histórico:
    /// así el listado refleja lo que se está escuchando ahora. La ventana es deslizante
    /// (7 días desde la última reproducción), de modo que una canción en rotación se
    /// mantiene en el ranking. Las caducadas ya fueron descartadas por `activeCounts()`.
    ///
    /// Cuando no queda ranking de ventana —una semana sin escuchar nada— se cae al
    /// `playCount` histórico en lugar de devolver una lista vacía, que es lo que dejaba
    /// la sección de Inicio en blanco. Sigue siendo un ranking de verdad, y en cuanto se
    /// reproduzca algo la ventana vuelve a mandar.
    func getTopSongs(limit: Int = 10) async throws -> [Song] {
        let counts = await rankingWindowRepository.activeCounts()
        let stats = try playStatsDataSource.allStats()

        // `getDownloaded()` excluye canciones sin descargar: al quitar una descarga sale
        // del ranking aunque conserve su ventana (se limpia sola al caducar).
        let downloaded = try localDataSource.getDownloaded()

        let windowed = rank(downloaded.filter { counts[$0.id] != nil }, limit: limit) {
            counts[$0.id] ?? 0
        }

        // El respaldo se decide sobre el **resultado**, no sobre si `counts` está vacío.
        // Una ventana viva puede pertenecer solo a canciones cuya descarga se quitó —su
        // entrada sobrevive hasta caducar, y `updateDownloadStatus` no la toca—, y entonces
        // `counts` viene lleno pero no hay nada que mostrar.
        guard windowed.isEmpty else { return SongMapper.toDomain(windowed, stats: stats) }

        // Las de `playCount == 0` quedan fuera: en una biblioteca recién descargada la
        // sección sí debe salir vacía, no listar todo por orden alfabético bajo "lo que
        // más escuchas".
        let historic = rank(downloaded.filter { (stats[$0.id]?.playCount ?? 0) > 0 }, limit: limit) {
            stats[$0.id]?.playCount ?? 0
        }
        return SongMapper.toDomain(historic, stats: stats)
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

    /// "Recientes" de Inicio.
    ///
    /// El orden lo da `SongPlayStatsDTO` (una fila por canción escuchada, no por canción de
    /// la biblioteca). El filtro de descargadas va **después** del orden y no en la propia
    /// consulta: así quitar una descarga la saca de Recientes, y recortar a `limit` antes
    /// de filtrar dejaría huecos en la lista.
    func getRecentlyPlayed(limit: Int = 10) async throws -> [Song] {
        let orderedIDs = try playStatsDataSource.recentlyPlayedIDs()
        guard !orderedIDs.isEmpty else { return [] }

        let downloaded = try localDataSource.getDownloaded(ids: orderedIDs)
        let byID = Dictionary(uniqueKeysWithValues: downloaded.map { ($0.id, $0) })
        let dtos = Array(orderedIDs.compactMap { byID[$0] }.prefix(limit))

        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
    }

    func search(query: String) async throws -> [Song] {
        let dtos = try localDataSource.search(query: query)
        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
    }

    func searchByAlbum(query: String) async throws -> [Song] {
        let dtos = try localDataSource.searchByAlbum(query: query)
        return SongMapper.toDomain(dtos, stats: try playStatsDataSource.allStats())
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
        try playStatsDataSource.delete(songID: id)
        await rankingWindowRepository.remove(songID: id)
    }

    func deleteAll() async throws {
        try localDataSource.deleteAll()
        try playStatsDataSource.deleteAll()
        await rankingWindowRepository.clear()
    }

    // MARK: - Specific Operations

    /// Dar al play. Escribe en `SongPlayStatsDTO` y en la ventana del ranking, **nunca** en
    /// `SongDTO`: es lo que evita que una reproducción invalide las cuatro listas.
    func incrementPlayCount(for id: UUID) async throws {
        try playStatsDataSource.increment(songID: id)
        // Abre o incrementa la ventana de 7 días de esta canción en el ranking de Inicio.
        await rankingWindowRepository.registerPlay(songID: id)
    }

    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) async throws {
        try localDataSource.updateDownloadStatus(for: id, isDownloaded: isDownloaded)
    }

}

// MARK: - Sendable Conformance

extension SongRepositoryImpl: Sendable {}
