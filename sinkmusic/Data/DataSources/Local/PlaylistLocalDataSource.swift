//
//  PlaylistLocalDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// DataSource para acceso local a playlists usando SwiftData
/// Encapsula toda la interacción con SwiftData. La reactividad hacia la UI
/// ocurre "gratis" vía `ModelContext.didSave` (ver `ModelContextChangeObserver`),
/// así que este tipo ya no necesita notificar nada explícitamente tras `save()`.
@MainActor
final class PlaylistLocalDataSource {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Lifecycle

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
    }

    /// Actualiza una playlist existente
    func update(_ playlist: PlaylistDTO) throws {
        playlist.updatedAt = Date()
        try modelContext.save()
    }

    /// Elimina una playlist por ID
    func delete(_ id: UUID) throws {
        guard let playlist = try getByID(id) else { return }
        modelContext.delete(playlist)
        try modelContext.save()
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
        // Mantener songOrder sincronizado con el array actual
        playlist.songOrder = playlist.songs.map { $0.id.uuidString }.joined(separator: ",")
        playlist.updatedAt = Date()
        try modelContext.save()
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
        // Mantener songOrder sincronizado
        playlist.songOrder = playlist.songs.map { $0.id.uuidString }.joined(separator: ",")
        playlist.updatedAt = Date()
        try modelContext.save()
    }

    /// Reordena las canciones en una playlist
    func updateSongsOrder(playlistID: UUID, songIDs: [UUID], songDataSource: SongLocalDataSource) throws {
        guard let playlist = try getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        // Reconstruir el array de SongDTO en el nuevo orden
        var reorderedSongs: [SongDTO] = []
        for songID in songIDs {
            if let song = try songDataSource.getByID(songID) {
                reorderedSongs.append(song)
            }
        }

        playlist.songs = reorderedSongs
        // Guardar el orden como string de UUIDs — fuente de verdad para el orden
        playlist.songOrder = songIDs.map { $0.uuidString }.joined(separator: ",")
        playlist.updatedAt = Date()
        try modelContext.save()
    }

}
