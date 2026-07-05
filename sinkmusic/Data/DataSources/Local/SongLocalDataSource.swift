//
//  SongLocalDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// DataSource para acceso local a canciones usando SwiftData
/// Encapsula toda la interacción con SwiftData. La reactividad hacia la UI
/// ocurre "gratis" vía `ModelContext.didSave` (ver `ModelContextChangeObserver`),
/// así que este tipo ya no necesita notificar nada explícitamente tras `save()`.
@MainActor
final class SongLocalDataSource {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Lifecycle

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    /// Obtiene todas las canciones ordenadas por título
    func getAll() throws -> [SongDTO] {
        let descriptor = FetchDescriptor<SongDTO>(
            sortBy: [SortDescriptor(\SongDTO.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene canciones con un predicado personalizado
    func fetch(with predicate: Predicate<SongDTO>?, sortBy: [SortDescriptor<SongDTO>] = []) throws -> [SongDTO] {
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: sortBy
        )
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene una canción por ID
    func getByID(_ id: UUID) throws -> SongDTO? {
        let predicate = #Predicate<SongDTO> { $0.id == id }
        let descriptor = FetchDescriptor<SongDTO>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    /// Obtiene una canción por fileID (Google Drive)
    func getByFileID(_ fileID: String) throws -> SongDTO? {
        let predicate = #Predicate<SongDTO> { $0.fileID == fileID }
        let descriptor = FetchDescriptor<SongDTO>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    /// Obtiene canciones descargadas
    func getDownloaded() throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> { $0.isDownloaded == true }
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene canciones pendientes de descarga
    func getPending() throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> { $0.isDownloaded == false }
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene top canciones por playCount (query targeted: predicate + sort + fetchLimit a nivel SwiftData)
    func getTopSongs(limit: Int = 10) throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> { $0.playCount > 0 }
        var descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.playCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    /// Obtiene canciones reproducidas recientemente (query targeted: reemplaza getAll()+filter+sort+prefix)
    func getRecentlyPlayed(limit: Int = 10) throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> { $0.lastPlayedAt != nil }
        var descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    /// Busca canciones cuyo título o artista contengan `query` (búsqueda targeted a nivel SwiftData)
    func search(query: String) throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> {
            $0.title.localizedStandardContains(query) || $0.artist.localizedStandardContains(query)
        }
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Busca canciones cuyo álbum contenga `query` (query targeted separada de `search`,
    /// porque `album` es opcional y `#Predicate` con `||` sobre `String?.contains` tiene
    /// limitaciones de macro-expansion en SwiftData al combinarlo con campos no opcionales).
    func searchByAlbum(query: String) throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> {
            $0.album != nil && $0.album!.localizedStandardContains(query)
        }
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Crea una nueva canción
    func create(_ song: SongDTO) throws {
        modelContext.insert(song)
        try modelContext.save()
    }

    /// Actualiza una canción existente
    func update(_ song: SongDTO) throws {
        guard let existing = try getByID(song.id) else { return }

        // Copiar propiedades del DTO recibido al objeto persistido
        existing.title = song.title
        existing.artist = song.artist
        existing.album = song.album
        existing.author = song.author
        existing.fileID = song.fileID
        existing.isDownloaded = song.isDownloaded
        existing.duration = song.duration
        existing.artworkData = song.artworkData
        existing.artworkThumbnail = song.artworkThumbnail
        existing.artworkMediumThumbnail = song.artworkMediumThumbnail
        existing.playCount = song.playCount
        existing.lastPlayedAt = song.lastPlayedAt
        existing.cachedDominantColorRed = song.cachedDominantColorRed
        existing.cachedDominantColorGreen = song.cachedDominantColorGreen
        existing.cachedDominantColorBlue = song.cachedDominantColorBlue

        try modelContext.save()
    }

    /// Elimina una canción por ID
    func delete(_ id: UUID) throws {
        guard let song = try getByID(id) else { return }
        modelContext.delete(song)
        try modelContext.save()
    }

    /// Elimina todas las canciones
    func deleteAll() throws {
        let allSongs = try getAll()
        for song in allSongs {
            modelContext.delete(song)
        }
        try modelContext.save()
    }

    // MARK: - Batch Operations

    /// Incrementa el contador de reproducciones
    func incrementPlayCount(for id: UUID) throws {
        guard let song = try getByID(id) else { return }
        song.playCount += 1
        song.lastPlayedAt = Date()
        try modelContext.save()
    }

    /// Actualiza el estado de descarga
    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) throws {
        guard let song = try getByID(id) else { return }
        song.isDownloaded = isDownloaded
        try modelContext.save()
    }

    /// Actualiza metadata de una canción
    func updateMetadata(
        for id: UUID,
        duration: TimeInterval?,
        artworkData: Data?,
        artworkThumbnail: Data?,
        artworkMediumThumbnail: Data?,
        album: String?,
        author: String?
    ) throws {
        guard let song = try getByID(id) else { return }

        if let duration = duration {
            song.duration = duration
        }
        if let artworkData = artworkData {
            song.artworkData = artworkData
        }
        if let artworkThumbnail = artworkThumbnail {
            song.artworkThumbnail = artworkThumbnail
        }
        if let artworkMediumThumbnail = artworkMediumThumbnail {
            song.artworkMediumThumbnail = artworkMediumThumbnail
        }
        if let album = album {
            song.album = album
        }
        if let author = author {
            song.author = author
        }

        try modelContext.save()
    }

}
