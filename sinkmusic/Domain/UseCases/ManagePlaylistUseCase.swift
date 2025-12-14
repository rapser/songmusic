//
//  ManagePlaylistUseCase.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

/// Casos de uso para gestionar playlists
/// Implementa Single Responsibility para operaciones de playlist
final class ManagePlaylistUseCase {
    private let playlistRepository: PlaylistRepositoryProtocol
    
    init(playlistRepository: PlaylistRepositoryProtocol) {
        self.playlistRepository = playlistRepository
    }
    
    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String = "", coverImageData: Data? = nil) throws {
        let playlist = Playlist(
            name: name,
            description: description,
            coverImageData: coverImageData
        )
        
        try playlistRepository.save(playlist)
    }
    
    /// Elimina una playlist
    func deletePlaylist(_ playlist: Playlist) throws {
        try playlistRepository.delete(playlist)
    }
    
    /// Actualiza una playlist
    func updatePlaylist(
        _ playlist: Playlist,
        name: String? = nil,
        description: String? = nil,
        coverImageData: Data? = nil
    ) throws {
        if let name = name {
            playlist.name = name
        }
        if let description = description {
            playlist.desc = description
        }
        if let coverImageData = coverImageData {
            playlist.coverImageData = coverImageData
        }
        
        try playlistRepository.update(playlist)
    }
    
    /// Agrega una canción a una playlist
    func addSong(_ song: Song, to playlist: Playlist) throws {
        try playlistRepository.addSong(song, to: playlist)
    }
    
    /// Elimina una canción de una playlist
    func removeSong(_ song: Song, from playlist: Playlist) throws {
        try playlistRepository.removeSong(song, from: playlist)
    }
}
