//
//  PlaylistUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para gestión de playlists
/// Maneja creación, edición y organización de playlists
@MainActor
final class PlaylistUseCases {

    // MARK: - Dependencies

    private let playlistRepository: PlaylistRepositoryProtocol
    private let songRepository: SongRepositoryProtocol

    // MARK: - Initialization

    init(
        playlistRepository: PlaylistRepositoryProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.playlistRepository = playlistRepository
        self.songRepository = songRepository
    }

    // MARK: - Playlist Access

    /// Obtiene todas las playlists
    func getAllPlaylists() async throws -> [PlaylistEntity] {
        return try await playlistRepository.getAll()
    }

    /// Obtiene una playlist por ID
    func getPlaylistByID(_ id: UUID) async throws -> PlaylistEntity? {
        return try await playlistRepository.getByID(id)
    }

    /// Observa cambios en las playlists
    func observePlaylistChanges(onChange: @escaping @MainActor ([PlaylistEntity]) -> Void) {
        playlistRepository.observeChanges(onChange: onChange)
    }

    // MARK: - Playlist Management

    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String?) async throws -> PlaylistEntity {
        let newPlaylist = PlaylistEntity(
            id: UUID(),
            name: name,
            description: description,
            coverImageData: nil,
            createdAt: Date(),
            songIDs: []
        )

        return try await playlistRepository.create(newPlaylist)
    }

    /// Actualiza una playlist existente
    func updatePlaylist(_ playlist: PlaylistEntity) async throws {
        try await playlistRepository.update(playlist)
    }

    /// Elimina una playlist
    func deletePlaylist(_ id: UUID) async throws {
        try await playlistRepository.delete(id)
    }

    /// Renombra una playlist
    func renamePlaylist(_ id: UUID, newName: String) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.playlistNotFound
        }

        playlist = PlaylistEntity(
            id: playlist.id,
            name: newName,
            description: playlist.description,
            coverImageData: playlist.coverImageData,
            createdAt: playlist.createdAt,
            songIDs: playlist.songIDs
        )

        try await playlistRepository.update(playlist)
    }

    // MARK: - Song Management in Playlist

    /// Agrega una canción a una playlist
    func addSongToPlaylist(songID: UUID, playlistID: UUID) async throws {
        // Verificar que la canción existe
        guard try await songRepository.getByID(songID) != nil else {
            throw PlaylistError.songNotFound
        }

        try await playlistRepository.addSong(songID, to: playlistID)
    }

    /// Remueve una canción de una playlist
    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) async throws {
        try await playlistRepository.removeSong(songID, from: playlistID)
    }

    /// Agrega múltiples canciones a una playlist
    func addSongsToPlaylist(songIDs: [UUID], playlistID: UUID) async throws {
        for songID in songIDs {
            try await addSongToPlaylist(songID: songID, playlistID: playlistID)
        }
    }

    /// Obtiene las canciones de una playlist
    func getSongsInPlaylist(_ playlistID: UUID) async throws -> [SongEntity] {
        guard let playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.playlistNotFound
        }

        var songs: [SongEntity] = []
        for songID in playlist.songIDs {
            if let song = try await songRepository.getByID(songID) {
                songs.append(song)
            }
        }

        return songs
    }

    // MARK: - Playlist Organization

    /// Reordena canciones en una playlist
    func reorderSongs(in playlistID: UUID, fromOffsets: IndexSet, toOffset: Int) async throws {
        guard var playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.playlistNotFound
        }

        var songIDs = playlist.songIDs
        songIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)

        playlist = PlaylistEntity(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            coverImageData: playlist.coverImageData,
            createdAt: playlist.createdAt,
            songIDs: songIDs
        )

        try await playlistRepository.update(playlist)
    }

    /// Limpia una playlist (remueve todas las canciones)
    func clearPlaylist(_ id: UUID) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.playlistNotFound
        }

        playlist = PlaylistEntity(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            coverImageData: playlist.coverImageData,
            createdAt: playlist.createdAt,
            songIDs: []
        )

        try await playlistRepository.update(playlist)
    }

    // MARK: - Statistics

    /// Obtiene estadísticas de una playlist
    func getPlaylistStats(_ id: UUID) async throws -> PlaylistStats {
        guard let playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.playlistNotFound
        }

        let songs = try await getSongsInPlaylist(id)
        let totalDuration = songs.compactMap { $0.duration }.reduce(0, +)
        let totalPlays = songs.map { $0.playCount }.reduce(0, +)
        let downloadedSongs = songs.filter { $0.isDownloaded }.count

        return PlaylistStats(
            songCount: playlist.songIDs.count,
            totalDuration: totalDuration,
            totalPlays: totalPlays,
            downloadedSongs: downloadedSongs
        )
    }
}

// MARK: - Playlist Stats

struct PlaylistStats: Sendable {
    let songCount: Int
    let totalDuration: TimeInterval
    let totalPlays: Int
    let downloadedSongs: Int

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Sendable Conformance

extension PlaylistUseCases: Sendable {}
