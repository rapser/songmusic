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

    func getTopSongs(limit: Int = 10) async throws -> [Song] {
        let dtos = try localDataSource.getTopSongs(limit: limit)
        return SongMapper.toDomain(dtos)
    }

    // MARK: - Mutation Operations

    func create(_ song: Song) async throws {
        let dto = SongMapper.toDTO(song)
        try localDataSource.create(dto)
    }

    func update(_ song: Song) async throws {
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

}

// MARK: - Sendable Conformance

extension SongRepositoryImpl: Sendable {}
