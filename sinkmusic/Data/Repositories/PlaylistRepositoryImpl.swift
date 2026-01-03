//
//  PlaylistRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Implementación del repositorio de playlists
/// Transforma entre DTOs (Data) y Entities (Domain) usando PlaylistMapper
@MainActor
final class PlaylistRepositoryImpl: PlaylistRepositoryProtocol {

    // MARK: - Properties

    private let localDataSource: PlaylistLocalDataSource
    private let songRepository: SongRepositoryProtocol

    // MARK: - Lifecycle

    init(localDataSource: PlaylistLocalDataSource, songRepository: SongRepositoryProtocol) {
        self.localDataSource = localDataSource
        self.songRepository = songRepository
    }

    // MARK: - Query Operations

    func getAll() async throws -> [PlaylistEntity] {
        let dtos = try localDataSource.getAll()
        return PlaylistMapper.toEntities(dtos)
    }

    func getByID(_ id: UUID) async throws -> PlaylistEntity? {
        guard let dto = try localDataSource.getByID(id) else { return nil }
        return PlaylistMapper.toEntityWithSongs(dto)
    }

    // MARK: - Mutation Operations

    func create(_ playlist: PlaylistEntity) async throws -> PlaylistEntity {
        let dto = PlaylistMapper.toDTO(playlist)
        try localDataSource.create(dto)
        // Retornar la entidad creada con su ID
        return playlist
    }

    func update(_ playlist: PlaylistEntity) async throws {
        guard let dto = try localDataSource.getByID(playlist.id) else {
            throw PlaylistError.notFound
        }

        dto.name = playlist.name
        dto.desc = playlist.description
        dto.coverImageData = playlist.coverImageData

        try localDataSource.update(dto)
    }

    func delete(_ id: UUID) async throws {
        try localDataSource.delete(id)
    }

    // MARK: - Song Management

    func addSong(songID: UUID, toPlaylist playlistID: UUID) async throws {
        // Obtener SongLocalDataSource del mismo contexto
        // Nota: En este caso, asumimos que se maneja internamente
        // o se pasa como dependencia si es necesario
        throw PlaylistError.invalidOperation("Use PlaylistUseCases for song management")
    }

    func removeSong(songID: UUID, fromPlaylist playlistID: UUID) async throws {
        try localDataSource.removeSong(songID: songID, fromPlaylist: playlistID)
    }

    func updateSongsOrder(playlistID: UUID, songIDs: [UUID]) async throws {
        // Similar al addSong, necesitaría el SongLocalDataSource
        throw PlaylistError.invalidOperation("Use PlaylistUseCases for song reordering")
    }

    // MARK: - Observability

    func observeChanges(onChange: @escaping @MainActor ([PlaylistEntity]) -> Void) {
        localDataSource.observeChanges { dtos in
            let entities = PlaylistMapper.toEntities(dtos)
            onChange(entities)
        }
    }
}

// MARK: - Sendable Conformance

extension PlaylistRepositoryImpl: Sendable {}
