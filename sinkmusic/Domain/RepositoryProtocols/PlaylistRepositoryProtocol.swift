//
//  PlaylistRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para operaciones con playlists
/// Define el contrato entre la capa de dominio y la capa de datos
protocol PlaylistRepositoryProtocol: Sendable {

    // MARK: - Query Operations

    /// Obtiene todas las playlists
    func getAll() async throws -> [Playlist]

    /// Obtiene una playlist por ID
    func getByID(_ id: UUID) async throws -> Playlist?

    // MARK: - Mutation Operations

    /// Crea una nueva playlist
    func create(_ playlist: Playlist) async throws -> Playlist

    /// Actualiza una playlist existente
    func update(_ playlist: Playlist) async throws

    /// Elimina una playlist
    func delete(_ id: UUID) async throws

    // MARK: - Song Management

    /// Agrega una canción a una playlist
    func addSong(songID: UUID, toPlaylist playlistID: UUID) async throws

    /// Elimina una canción de una playlist
    func removeSong(songID: UUID, fromPlaylist playlistID: UUID) async throws

    /// Reordena las canciones en una playlist
    func updateSongsOrder(playlistID: UUID, songIDs: [UUID]) async throws

}
