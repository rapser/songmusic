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

    // MARK: - Lifecycle

    init(localDataSource: SongLocalDataSource) {
        self.localDataSource = localDataSource
    }

    // MARK: - Query Operations

    func getAll() async throws -> [SongEntity] {
        let dtos = try localDataSource.getAll()
        return SongMapper.toEntities(dtos)
    }

    func getByID(_ id: UUID) async throws -> SongEntity? {
        guard let dto = try localDataSource.getByID(id) else { return nil }
        return SongMapper.toEntity(dto)
    }

    func getByFileID(_ fileID: String) async throws -> SongEntity? {
        guard let dto = try localDataSource.getByFileID(fileID) else { return nil }
        return SongMapper.toEntity(dto)
    }

    func getDownloaded() async throws -> [SongEntity] {
        let dtos = try localDataSource.getDownloaded()
        return SongMapper.toEntities(dtos)
    }

    func getPending() async throws -> [SongEntity] {
        let dtos = try localDataSource.getPending()
        return SongMapper.toEntities(dtos)
    }

    func getTopSongs(limit: Int = 10) async throws -> [SongEntity] {
        let dtos = try localDataSource.getTopSongs(limit: limit)
        return SongMapper.toEntities(dtos)
    }

    // MARK: - Mutation Operations

    func create(_ song: SongEntity) async throws {
        let dto = SongMapper.toDTO(song)
        try localDataSource.create(dto)
    }

    func update(_ song: SongEntity) async throws {
        let dto = SongMapper.toDTO(song)
        try localDataSource.update(dto)
    }

    func delete(_ id: UUID) async throws {
        try localDataSource.delete(id)
    }

    func deleteAll() async throws {
        try localDataSource.deleteAll()
    }

    // MARK: - Specific Operations

    func incrementPlayCount(for id: UUID) async throws {
        try localDataSource.incrementPlayCount(for: id)
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

    // MARK: - Observability

    func observeChanges(onChange: @escaping @MainActor ([SongEntity]) -> Void) {
        localDataSource.observeChanges { dtos in
            let entities = SongMapper.toEntities(dtos)
            onChange(entities)
        }
    }
}

// MARK: - Sendable Conformance

extension SongRepositoryImpl: Sendable {}
