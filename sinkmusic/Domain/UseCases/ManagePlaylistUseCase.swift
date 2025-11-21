//
//  ManagePlaylistUseCase.swift
//  sinkmusic
//
//  Created by Refactoring - Use Case Pattern
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
        print("✅ Playlist '\(name)' creada")
    }
    
    /// Elimina una playlist
    func deletePlaylist(_ playlist: Playlist) throws {
        try playlistRepository.delete(playlist)
        print("✅ Playlist '\(playlist.name)' eliminada")
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
        print("✅ Playlist actualizada")
    }
    
    /// Agrega una canción a una playlist
    func addSong(_ song: Song, to playlist: Playlist) throws {
        try playlistRepository.addSong(song, to: playlist)
        print("✅ Canción '\(song.title)' agregada a '\(playlist.name)'")
    }
    
    /// Elimina una canción de una playlist
    func removeSong(_ song: Song, from playlist: Playlist) throws {
        try playlistRepository.removeSong(song, from: playlist)
        print("✅ Canción '\(song.title)' eliminada de '\(playlist.name)'")
    }
}
