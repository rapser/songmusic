//
//  PlaylistViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI de playlists
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de playlists
/// Delega lógica de negocio a PlaylistUseCases
@MainActor
@Observable
final class PlaylistViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var playlists: [PlaylistUIModel] = []
    var selectedPlaylist: PlaylistUIModel?
    var songsInPlaylist: [SongUIModel] = []
    var playlistStats: PlaylistStats?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let playlistUseCases: PlaylistUseCases

    // MARK: - Initialization

    init(playlistUseCases: PlaylistUseCases) {
        self.playlistUseCases = playlistUseCases
        setupObservers()
        Task {
            await loadPlaylists()
        }
    }

    // MARK: - Playlist Operations

    /// Carga todas las playlists
    func loadPlaylists() async {
        do {
            let entities = try await playlistUseCases.getAllPlaylists()
            playlists = entities.map { PlaylistMapper.toUIModel($0) }
        } catch {
            errorMessage = "Error al cargar playlists: \(error.localizedDescription)"
        }
    }

    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String?, coverImageData: Data?) async throws -> UUID {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nombre de la playlist no puede estar vacío"
            throw PlaylistError.emptyName
        }

        isLoading = true
        do {
            let playlist = try await playlistUseCases.createPlaylist(name: name, description: description, coverImageData: coverImageData)
            await loadPlaylists()
            errorMessage = nil
            isLoading = false
            return playlist.id
        } catch {
            errorMessage = "Error al crear playlist: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    /// Actualiza una playlist existente
    func updatePlaylist(id: UUID, name: String, description: String?, coverImageData: Data?) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nombre de la playlist no puede estar vacío"
            return
        }

        isLoading = true
        do {
            // Obtener la playlist actual para mantener otros datos
            guard let currentPlaylist = try await playlistUseCases.getPlaylistByID(id) else {
                errorMessage = "Playlist no encontrada"
                isLoading = false
                return
            }

            // Crear una nueva entidad con los valores actualizados
            let updatedPlaylist = PlaylistEntity(
                id: currentPlaylist.id,
                name: name,
                description: description ?? "",
                createdAt: currentPlaylist.createdAt,
                updatedAt: Date(),
                coverImageData: coverImageData,
                songs: currentPlaylist.songs
            )

            try await playlistUseCases.updatePlaylist(updatedPlaylist)
            await loadPlaylists()

            // Actualizar la playlist seleccionada si es la que se editó
            if selectedPlaylist?.id == id {
                selectedPlaylist = PlaylistMapper.toUIModel(updatedPlaylist)
            }

            errorMessage = nil
        } catch {
            errorMessage = "Error al actualizar playlist: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Elimina una playlist
    func deletePlaylist(_ id: UUID) async {
        isLoading = true
        do {
            try await playlistUseCases.deletePlaylist(id)
            await loadPlaylists()
            if selectedPlaylist?.id == id {
                selectedPlaylist = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = "Error al eliminar playlist: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Renombra una playlist
    func renamePlaylist(_ id: UUID, newName: String) async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nuevo nombre no puede estar vacío"
            return
        }

        isLoading = true
        do {
            try await playlistUseCases.renamePlaylist(id, newName: newName)
            await loadPlaylists()
            if let playlist = try? await playlistUseCases.getPlaylistByID(id) {
                selectedPlaylist = PlaylistMapper.toUIModel(playlist)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Error al renombrar playlist: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Song Management

    /// Agrega una canción a la playlist
    func addSongToPlaylist(songID: UUID, playlistID: UUID) async {
        do {
            try await playlistUseCases.addSongToPlaylist(songID: songID, playlistID: playlistID)
            await loadSongsInPlaylist(playlistID)
            await loadPlaylistStats(playlistID)
            errorMessage = nil
        } catch {
            errorMessage = "Error al agregar canción: \(error.localizedDescription)"
        }
    }

    /// Remueve una canción de la playlist
    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) async {
        do {
            try await playlistUseCases.removeSongFromPlaylist(songID: songID, playlistID: playlistID)
            await loadSongsInPlaylist(playlistID)
            await loadPlaylistStats(playlistID)
            errorMessage = nil
        } catch {
            errorMessage = "Error al remover canción: \(error.localizedDescription)"
        }
    }

    /// Agrega múltiples canciones a la playlist
    func addSongsToPlaylist(songIDs: [UUID], playlistID: UUID) async {
        isLoading = true
        do {
            try await playlistUseCases.addSongsToPlaylist(songIDs: songIDs, playlistID: playlistID)
            await loadSongsInPlaylist(playlistID)
            await loadPlaylistStats(playlistID)
            errorMessage = nil
        } catch {
            errorMessage = "Error al agregar canciones: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Reordena canciones en la playlist
    func reorderSongs(in playlistID: UUID, fromOffsets: IndexSet, toOffset: Int) async {
        do {
            try await playlistUseCases.reorderSongs(in: playlistID, fromOffsets: fromOffsets, toOffset: toOffset)
            await loadSongsInPlaylist(playlistID)
            errorMessage = nil
        } catch {
            errorMessage = "Error al reordenar canciones: \(error.localizedDescription)"
        }
    }

    /// Limpia todas las canciones de la playlist
    func clearPlaylist(_ id: UUID) async {
        isLoading = true
        do {
            try await playlistUseCases.clearPlaylist(id)
            await loadSongsInPlaylist(id)
            await loadPlaylistStats(id)
            errorMessage = nil
        } catch {
            errorMessage = "Error al limpiar playlist: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Detail View

    /// Carga las canciones de una playlist
    func loadSongsInPlaylist(_ playlistID: UUID) async {
        do {
            let entities = try await playlistUseCases.getSongsInPlaylist(playlistID)
            songsInPlaylist = entities.map { SongMapper.toUIModel($0) }
        } catch {
            errorMessage = "Error al cargar canciones: \(error.localizedDescription)"
        }
    }

    /// Selecciona una playlist para ver en detalle
    func selectPlaylist(_ playlist: PlaylistUIModel) async {
        selectedPlaylist = playlist
        await loadSongsInPlaylist(playlist.id)
        await loadPlaylistStats(playlist.id)
    }

    // MARK: - Statistics

    /// Carga estadísticas de una playlist
    func loadPlaylistStats(_ playlistID: UUID) async {
        do {
            playlistStats = try await playlistUseCases.getPlaylistStats(playlistID)
        } catch {
            print("❌ Error al cargar estadísticas: \(error)")
        }
    }

    // MARK: - Helpers

    /// Verifica si una canción está en alguna playlist
    func isSongInAnyPlaylist(songID: UUID) -> Bool {
        return playlists.contains { playlist in
            playlist.songs.contains(where: { $0.id == songID })
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observar cambios en playlists
        playlistUseCases.observePlaylistChanges { [weak self] updatedPlaylists in
            guard let self = self else { return }
            self.playlists = updatedPlaylists.map { PlaylistMapper.toUIModel($0) }

            // Si hay una playlist seleccionada, actualizarla
            if let selectedID = self.selectedPlaylist?.id,
               let updatedPlaylist = updatedPlaylists.first(where: { $0.id == selectedID }) {
                self.selectedPlaylist = PlaylistMapper.toUIModel(updatedPlaylist)
                Task {
                    await self.loadSongsInPlaylist(selectedID)
                    await self.loadPlaylistStats(selectedID)
                }
            }
        }
    }
}
