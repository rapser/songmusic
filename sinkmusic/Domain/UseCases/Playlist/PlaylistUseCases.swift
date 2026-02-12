//
//  PlaylistUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
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
    func getAllPlaylists() async throws -> [Playlist] {
        return try await playlistRepository.getAll()
    }

    /// Obtiene una playlist por ID
    func getPlaylistByID(_ id: UUID) async throws -> Playlist? {
        return try await playlistRepository.getByID(id)
    }

    // MARK: - Playlist Management

    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String?, coverImageData: Data?) async throws -> Playlist {
        let newPlaylist = Playlist(
            id: UUID(),
            name: name,
            description: description ?? "",
            createdAt: Date(),
            updatedAt: Date(),
            coverImageData: coverImageData,
            songs: []
        )

        return try await playlistRepository.create(newPlaylist)
    }

    /// Actualiza una playlist existente
    func updatePlaylist(_ playlist: Playlist) async throws {
        try await playlistRepository.update(playlist)
    }

    /// Elimina una playlist
    func deletePlaylist(_ id: UUID) async throws {
        try await playlistRepository.delete(id)
    }

    /// Renombra una playlist
    func renamePlaylist(_ id: UUID, newName: String) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        playlist = Playlist(
            id: playlist.id,
            name: newName,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: Date(),
            coverImageData: playlist.coverImageData,
            songs: playlist.songs
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

        try await playlistRepository.addSong(songID: songID, toPlaylist: playlistID)
    }

    /// Remueve una canción de una playlist
    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) async throws {
        try await playlistRepository.removeSong(songID: songID, fromPlaylist: playlistID)
    }

    /// Agrega múltiples canciones a una playlist
    func addSongsToPlaylist(songIDs: [UUID], playlistID: UUID) async throws {
        for songID in songIDs {
            try await addSongToPlaylist(songID: songID, playlistID: playlistID)
        }
    }

    /// Obtiene las canciones de una playlist
    func getSongsInPlaylist(_ playlistID: UUID) async throws -> [Song] {
        guard let playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        return playlist.songs
    }

    // MARK: - Playlist Organization

    /// Reordena canciones en una playlist
    func reorderSongs(in playlistID: UUID, fromOffsets: IndexSet, toOffset: Int) async throws {
        guard let playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        // Reordenar el array de IDs y persistir con updateSongsOrder,
        // que escribe directamente playlist.songs en SwiftData.
        // update() no toca el array de canciones — por eso el orden se perdía.
        var songIDs = playlist.songs.map { $0.id }
        songIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)

        try await playlistRepository.updateSongsOrder(playlistID: playlistID, songIDs: songIDs)
    }

    /// Limpia una playlist (remueve todas las canciones)
    func clearPlaylist(_ id: UUID) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        playlist = Playlist(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: Date(),
            coverImageData: playlist.coverImageData,
            songs: []
        )

        try await playlistRepository.update(playlist)
    }

    // MARK: - Statistics

    /// Obtiene estadísticas de una playlist
    func getPlaylistStats(_ id: UUID) async throws -> PlaylistStats {
        guard let playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        let songs = try await getSongsInPlaylist(id)
        let totalDuration = songs.compactMap { $0.duration }.reduce(0, +)
        let totalPlays = songs.map { $0.playCount }.reduce(0, +)
        let downloadedSongs = songs.filter { $0.isDownloaded }.count

        return PlaylistStats(
            songCount: playlist.songs.count,
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
