//
//  PlaylistViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Maneja UI de playlists
//

import Foundation
import SwiftUI
import os

/// ViewModel responsable de la UI de playlists
/// Delega mutaciones a PlaylistUseCases y lectura reactiva a PlaylistReadStoreProtocol
/// (que reacciona a cambios de SwiftData sin pasar por el EventBus global).
@MainActor
@Observable
final class PlaylistViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var playlists: [PlaylistUI] = []
    var selectedPlaylist: PlaylistUI?
    var songsInPlaylist: [SongUI] = []
    var playlistStats: PlaylistStats?
    var isLoading = false
    var errorMessage: String?

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Playlist")

    // MARK: - Dependencies

    private let playlistUseCases: PlaylistUseCases
    private let readStore: PlaylistReadStoreProtocol

    // MARK: - Tasks

    /// Task para observar cambios reactivos del ReadStore
    @ObservationIgnored
    private var changesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(playlistUseCases: PlaylistUseCases, readStore: PlaylistReadStoreProtocol) {
        self.playlistUseCases = playlistUseCases
        self.readStore = readStore
        changesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in readStore.changes() {
                guard !Task.isCancelled else { break }
                await self.loadPlaylists()
                if let selectedID = self.selectedPlaylist?.id {
                    await self.loadSongsInPlaylist(selectedID)
                    await self.loadPlaylistStats(selectedID)
                }
            }
        }
        Task {
            await loadPlaylists()
        }
    }

    // MARK: - Playlist Operations

    /// Carga todas las playlists
    func loadPlaylists() async {
        await loadAndAssign(
            fetch: { try await readStore.allPlaylists() },
            map: { $0.map(PlaylistMapper.toUI) },
            assign: { playlists = $0 },
            onError: { [self] in errorMessage = "Error al cargar playlists: \($0.localizedDescription)" }
        )
    }

    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String?, coverImageData: Data?, placeholderColorIndex: Int? = nil) async throws -> UUID {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nombre de la playlist no puede estar vacío"
            throw PlaylistError.emptyName
        }

        isLoading = true
        do {
            let playlist = try await playlistUseCases.createPlaylist(name: name, description: description, coverImageData: coverImageData, placeholderColorIndex: placeholderColorIndex)
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
    func updatePlaylist(id: UUID, name: String, description: String?, coverImageData: Data?, placeholderColorIndex: Int? = nil) async {
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
            let updatedPlaylist = Playlist(
                id: currentPlaylist.id,
                name: name,
                description: description ?? "",
                createdAt: currentPlaylist.createdAt,
                updatedAt: Date(),
                coverImageData: coverImageData,
                placeholderColorIndex: placeholderColorIndex,
                songs: currentPlaylist.songs
            )

            try await playlistUseCases.updatePlaylist(updatedPlaylist)
            await loadPlaylists()

            // Actualizar la playlist seleccionada si es la que se editó
            if selectedPlaylist?.id == id {
                selectedPlaylist = PlaylistMapper.toUI(updatedPlaylist)
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
                selectedPlaylist = PlaylistMapper.toUI(playlist)
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
    /// Aplica el cambio de forma optimista en la UI antes de persistir para que
    /// el drag & drop se sienta inmediato sin esperar a SwiftData.
    func reorderSongs(in playlistID: UUID, fromOffsets: IndexSet, toOffset: Int) async {
        // Actualización optimista: mover en el array local primero
        songsInPlaylist.move(fromOffsets: fromOffsets, toOffset: toOffset)

        // Persistir en segundo plano
        do {
            try await playlistUseCases.reorderSongs(in: playlistID, fromOffsets: fromOffsets, toOffset: toOffset)
            errorMessage = nil
        } catch {
            // Revertir si falla la persistencia
            await loadSongsInPlaylist(playlistID)
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
            let entities = try await readStore.songs(inPlaylist: playlistID)
            songsInPlaylist = entities.map { SongMapper.toUI($0) }
        } catch {
            errorMessage = "Error al cargar canciones: \(error.localizedDescription)"
        }
    }

    /// Selecciona una playlist para ver en detalle
    func selectPlaylist(_ playlist: PlaylistUI) async {
        selectedPlaylist = playlist
        await loadSongsInPlaylist(playlist.id)
        await loadPlaylistStats(playlist.id)
    }

    // MARK: - Statistics

    /// Carga estadísticas de una playlist
    func loadPlaylistStats(_ playlistID: UUID) async {
        do {
            playlistStats = try await readStore.stats(forPlaylist: playlistID)
        } catch {
            logger.error("Error al cargar estadísticas de playlist: \(error)")
        }
    }

    // MARK: - Helpers

    /// Verifica si una canción está en alguna playlist
    func isSongInAnyPlaylist(songID: UUID) -> Bool {
        return playlists.contains { playlist in
            playlist.songs.contains(where: { $0.id == songID })
        }
    }

    // MARK: - Cleanup

    deinit {
        changesTask?.cancel()
    }
}
