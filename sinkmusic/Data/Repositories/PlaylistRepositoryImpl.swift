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
    private let songLocalDataSource: SongLocalDataSource

    // MARK: - Lifecycle

    init(
        localDataSource: PlaylistLocalDataSource,
        songRepository: SongRepositoryProtocol,
        songLocalDataSource: SongLocalDataSource
    ) {
        self.localDataSource = localDataSource
        self.songRepository = songRepository
        self.songLocalDataSource = songLocalDataSource
    }

    // MARK: - Query Operations

    func getAll() async throws -> [Playlist] {
        let dtos = try localDataSource.getAll()
        return PlaylistMapper.toDomain(dtos)
    }

    func getByID(_ id: UUID) async throws -> Playlist? {
        guard let dto = try localDataSource.getByID(id) else { return nil }
        return PlaylistMapper.toDomainWithSongs(dto)
    }

    // MARK: - Mutation Operations

    func create(_ playlist: Playlist) async throws -> Playlist {
        let dto = PlaylistMapper.toDTO(playlist)
        try localDataSource.create(dto)
        // Retornar la entidad creada con su ID
        return playlist
    }

    func update(_ playlist: Playlist) async throws {
        guard let dto = try localDataSource.getByID(playlist.id) else {
            throw PlaylistError.notFound
        }

        dto.name = playlist.name
        dto.desc = playlist.description
        dto.coverImageData = playlist.coverImageData
        dto.placeholderColorIndex = playlist.placeholderColorIndex

        try localDataSource.update(dto)
    }

    func delete(_ id: UUID) async throws {
        try localDataSource.delete(id)
    }

    // MARK: - Song Management

    func addSong(songID: UUID, toPlaylist playlistID: UUID) async throws {
        try localDataSource.addSong(
            songID: songID,
            toPlaylist: playlistID,
            songDataSource: songLocalDataSource
        )
    }

    func removeSong(songID: UUID, fromPlaylist playlistID: UUID) async throws {
        try localDataSource.removeSong(songID: songID, fromPlaylist: playlistID)
    }

    func updateSongsOrder(playlistID: UUID, songIDs: [UUID]) async throws {
        try localDataSource.updateSongsOrder(
            playlistID: playlistID,
            songIDs: songIDs,
            songDataSource: songLocalDataSource
        )
    }

}

// MARK: - Sendable Conformance

extension PlaylistRepositoryImpl: Sendable {}
