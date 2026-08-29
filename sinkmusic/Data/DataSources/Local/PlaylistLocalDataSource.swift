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

        let (items, _) = try syncedOrderItems(for: playlist)
        playlist.songs.append(song)
        modelContext.insert(PlaylistItemDTO(playlistID: playlistID, songID: songID, position: items.count))
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
        deleteOrderItems(playlistID: playlistID, songIDs: [songID])
        try renormalizePositions(for: playlistID)
        playlist.updatedAt = Date()
        try modelContext.save()
    }

    /// Elimina una canción de todas las playlists que la referencian.
    /// Se usa cuando una canción deja de existir o de estar descargada: el playlist se
    /// mantiene, pero no tiene sentido seguir mostrando una canción que ya no existe.
    /// El orden de las canciones restantes se preserva (los `PlaylistItemDTO` sobrantes
    /// se renormalizan, no se reconstruyen desde `songs`).
    func removeSongFromAllPlaylists(songID: UUID) throws {
        let playlists = try getAll()
        var didChange = false

        for playlist in playlists {
            guard playlist.songs.contains(where: { $0.id == songID }) else { continue }

            playlist.songs.removeAll { $0.id == songID }
            deleteOrderItems(playlistID: playlist.id, songIDs: [songID])
            try renormalizePositions(for: playlist.id)
            playlist.updatedAt = Date()
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
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
        // Reemplazar todos los items de orden por la nueva secuencia.
        deleteAllOrderItems(playlistID: playlistID)
        for (index, songID) in reorderedSongs.map(\.id).enumerated() {
            modelContext.insert(PlaylistItemDTO(playlistID: playlistID, songID: songID, position: index))
        }
        playlist.updatedAt = Date()
        try modelContext.save()
    }

    // MARK: - Orden (PlaylistItemDTO)

    /// Canciones de la playlist en su orden manual, resuelto vía `PlaylistItemDTO`.
    /// Hace backfill perezoso desde el `songOrder` legacy la primera vez y persiste el
    /// resultado solo si hubo cambios (migración puntual, no en cada lectura).
    func orderedSongs(for playlist: PlaylistDTO) throws -> [SongDTO] {
        let (items, didMutate) = try syncedOrderItems(for: playlist)
        if didMutate {
            try modelContext.save()
        }
        let byID = Dictionary(uniqueKeysWithValues: playlist.songs.map { ($0.id, $0) })
        return items.compactMap { byID[$0.songID] }
    }

    /// Devuelve los items de orden sincronizados con `playlist.songs` y si hubo que tocar el store:
    /// - Backfill: si no hay items, se crean desde `songOrder` (legacy) y, para lo que no
    ///   figure ahí, desde el orden actual de la relación.
    /// - Reconciliación: se descartan items de canciones ausentes y se añaden al final las
    ///   canciones sin item. Las posiciones quedan contiguas desde 0.
    /// No hace `save()` — el llamador decide según `didMutate` (ver `orderedSongs`).
    @discardableResult
    private func syncedOrderItems(for playlist: PlaylistDTO) throws -> (items: [PlaylistItemDTO], didMutate: Bool) {
        let playlistID = playlist.id
        let descriptor = FetchDescriptor<PlaylistItemDTO>(
            predicate: #Predicate<PlaylistItemDTO> { $0.playlistID == playlistID },
            sortBy: [SortDescriptor(\PlaylistItemDTO.position)]
        )
        var items = try modelContext.fetch(descriptor)
        let currentSongIDs = playlist.songs.map(\.id)
        let currentSet = Set(currentSongIDs)

        if items.isEmpty {
            guard !currentSongIDs.isEmpty else { return ([], false) }
            let legacyOrder = playlist.songOrder
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
                .filter { currentSet.contains($0) }
            let legacySet = Set(legacyOrder)
            let ordered = legacyOrder + currentSongIDs.filter { !legacySet.contains($0) }
            items = ordered.enumerated().map { index, songID in
                let item = PlaylistItemDTO(playlistID: playlistID, songID: songID, position: index)
                modelContext.insert(item)
                return item
            }
            return (items, true)
        }

        // Reconciliar con la relación actual.
        var didMutate = false
        let itemSet = Set(items.map(\.songID))
        for orphan in items where !currentSet.contains(orphan.songID) {
            modelContext.delete(orphan)
            didMutate = true
        }
        items.removeAll { !currentSet.contains($0.songID) }
        for songID in currentSongIDs where !itemSet.contains(songID) {
            let item = PlaylistItemDTO(playlistID: playlistID, songID: songID, position: items.count)
            modelContext.insert(item)
            items.append(item)
            didMutate = true
        }
        for (index, item) in items.enumerated() where item.position != index {
            item.position = index
            didMutate = true
        }
        return (items, didMutate)
    }

    private func orderItems(playlistID: UUID) throws -> [PlaylistItemDTO] {
        let descriptor = FetchDescriptor<PlaylistItemDTO>(
            predicate: #Predicate<PlaylistItemDTO> { $0.playlistID == playlistID },
            sortBy: [SortDescriptor(\PlaylistItemDTO.position)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func deleteOrderItems(playlistID: UUID, songIDs: Set<UUID>) {
        let descriptor = FetchDescriptor<PlaylistItemDTO>(
            predicate: #Predicate<PlaylistItemDTO> { $0.playlistID == playlistID }
        )
        guard let matches = try? modelContext.fetch(descriptor) else { return }
        for item in matches where songIDs.contains(item.songID) {
            modelContext.delete(item)
        }
    }

    private func deleteAllOrderItems(playlistID: UUID) {
        let descriptor = FetchDescriptor<PlaylistItemDTO>(
            predicate: #Predicate<PlaylistItemDTO> { $0.playlistID == playlistID }
        )
        guard let matches = try? modelContext.fetch(descriptor) else { return }
        matches.forEach { modelContext.delete($0) }
    }

    private func renormalizePositions(for playlistID: UUID) throws {
        let items = try orderItems(playlistID: playlistID)
        for (index, item) in items.enumerated() where item.position != index {
            item.position = index
        }
    }

}
