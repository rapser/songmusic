//
//  RefactoredPlaylistViewModel.swift
//  sinkmusic
//
//  Created by Refactoring - MVVM + SOLID
//

import Foundation
import SwiftData
import SwiftUI

/// ViewModel refactorizado para playlists
/// Implementa MVVM correctamente con inyección de dependencias y UseCases
@MainActor
final class RefactoredPlaylistViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var playlists: [Playlist] = []
    @Published var showCreatePlaylist = false
    @Published var showAddToPlaylist = false
    @Published var selectedSong: Song?
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let playlistRepository: PlaylistRepositoryProtocol
    private let managePlaylistUseCase: ManagePlaylistUseCase
    
    // MARK: - Initialization with Dependency Injection
    init(playlistRepository: PlaylistRepositoryProtocol) {
        self.playlistRepository = playlistRepository
        self.managePlaylistUseCase = ManagePlaylistUseCase(playlistRepository: playlistRepository)
        
        fetchPlaylists()
    }
    
    // MARK: - Public Methods
    func fetchPlaylists() {
        do {
            playlists = try playlistRepository.fetchAll()
        } catch {
            errorMessage = "Error al cargar playlists: \(error.localizedDescription)"
        }
    }
    
    func createPlaylist(name: String, description: String = "", coverImageData: Data? = nil) {
        do {
            try managePlaylistUseCase.createPlaylist(
                name: name,
                description: description,
                coverImageData: coverImageData
            )
            fetchPlaylists()
        } catch {
            errorMessage = "Error al crear playlist: \(error.localizedDescription)"
        }
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        do {
            try managePlaylistUseCase.deletePlaylist(playlist)
            fetchPlaylists()
        } catch {
            errorMessage = "Error al eliminar playlist: \(error.localizedDescription)"
        }
    }
    
    func updatePlaylist(
        _ playlist: Playlist,
        name: String? = nil,
        description: String? = nil,
        coverImageData: Data? = nil
    ) {
        do {
            try managePlaylistUseCase.updatePlaylist(
                playlist,
                name: name,
                description: description,
                coverImageData: coverImageData
            )
            fetchPlaylists()
        } catch {
            errorMessage = "Error al actualizar playlist: \(error.localizedDescription)"
        }
    }
    
    func addSong(_ song: Song, to playlist: Playlist) {
        do {
            try managePlaylistUseCase.addSong(song, to: playlist)
            fetchPlaylists()
        } catch {
            errorMessage = "Error al agregar canción: \(error.localizedDescription)"
        }
    }
    
    func removeSong(_ song: Song, from playlist: Playlist) {
        do {
            try managePlaylistUseCase.removeSong(song, from: playlist)
            fetchPlaylists()
        } catch {
            errorMessage = "Error al eliminar canción: \(error.localizedDescription)"
        }
    }
    
    func reorderSongs(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        playlist.songs.move(fromOffsets: source, toOffset: destination)
        
        do {
            try playlistRepository.update(playlist)
            fetchPlaylists()
        } catch {
            errorMessage = "Error al reordenar: \(error.localizedDescription)"
        }
    }
    
    func showAddToPlaylistSheet(for song: Song) {
        selectedSong = song
        showAddToPlaylist = true
    }
}
