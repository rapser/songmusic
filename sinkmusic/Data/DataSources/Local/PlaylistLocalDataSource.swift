//
//  PlaylistLocalDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// DataSource para acceso local a playlists usando SwiftData
/// Encapsula toda la interacción con SwiftData y proporciona observabilidad
/// SOLID: Dependency Inversion - Recibe EventBus por inyección
@MainActor
final class PlaylistLocalDataSource {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let notificationService: SwiftDataNotificationService

    // MARK: - Lifecycle

    init(modelContext: ModelContext, eventBus: EventBusProtocol) {
        self.modelContext = modelContext
        self.notificationService = SwiftDataNotificationService(modelContext: modelContext, eventBus: eventBus)
    }

    // MARK: - CRUD Operations

    /// Obtiene todas las playlists ordenadas por fecha de actualización
    func getAll() throws -> [PlaylistDTO] {
        let descriptor = FetchDescriptor<PlaylistDTO>(
            sortBy: [SortDescriptor(\PlaylistDTO.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene una playlist por ID
    func getByID(_ id: UUID) throws -> PlaylistDTO? {
        let predicate = #Predicate<PlaylistDTO> { $0.id == id }
        let descriptor = FetchDescriptor<PlaylistDTO>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    /// Crea una nueva playlist
    func create(_ playlist: PlaylistDTO) throws {
        modelContext.insert(playlist)
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Actualiza una playlist existente
    func update(_ playlist: PlaylistDTO) throws {
        playlist.updatedAt = Date()
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Elimina una playlist por ID
    func delete(_ id: UUID) throws {
        guard let playlist = try getByID(id) else { return }
        modelContext.delete(playlist)
        try modelContext.save()
        notificationService.notifyChange()
    }

    // MARK: - Song Management

    /// Agrega una canción a una playlist
    func addSong(songID: UUID, toPlaylist playlistID: UUID, songDataSource: SongLocalDataSource) throws {
        guard let playlist = try getByID(playlistID) else {
            throw PlaylistError.notFound
        }
        guard let song = try songDataSource.getByID(songID) else {
            throw SongError.fileNotFound
        }

        // Verificar si la canción ya está en la playlist
        guard !playlist.songs.contains(where: { $0.id == songID }) else {
            throw PlaylistError.songAlreadyExists
        }

        playlist.songs.append(song)
        playlist.updatedAt = Date()
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Elimina una canción de una playlist
    func removeSong(songID: UUID, fromPlaylist playlistID: UUID) throws {
        guard let playlist = try getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        guard let index = playlist.songs.firstIndex(where: { $0.id == songID }) else {
            throw PlaylistError.songNotFound
        }

        playlist.songs.remove(at: index)
        playlist.updatedAt = Date()
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Reordena las canciones en una playlist
    func updateSongsOrder(playlistID: UUID, songIDs: [UUID], songDataSource: SongLocalDataSource) throws {
        guard let playlist = try getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        // Reconstruir el array de canciones según el nuevo orden
        var reorderedSongs: [SongDTO] = []
        for songID in songIDs {
            if let song = try songDataSource.getByID(songID) {
                reorderedSongs.append(song)
            }
        }

        playlist.songs = reorderedSongs
        playlist.updatedAt = Date()
        try modelContext.save()
        notificationService.notifyChange()
    }

}
