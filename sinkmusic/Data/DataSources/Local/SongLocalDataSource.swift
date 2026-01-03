//
//  SongLocalDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// DataSource para acceso local a canciones usando SwiftData
/// Encapsula toda la interacción con SwiftData y proporciona observabilidad
@MainActor
final class SongLocalDataSource {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let notificationService: SwiftDataNotificationService

    // MARK: - Lifecycle

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.notificationService = SwiftDataNotificationService(modelContext: modelContext)
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
        var descriptor = FetchDescriptor<SongDTO>(
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

    /// Obtiene top canciones por playCount
    func getTopSongs(limit: Int = 10) throws -> [SongDTO] {
        let predicate = #Predicate<SongDTO> { $0.playCount > 0 }
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: predicate,
            sortBy: [SortDescriptor(\SongDTO.playCount, order: .reverse)]
        )
        let allTop = try modelContext.fetch(descriptor)
        return Array(allTop.prefix(limit))
    }

    /// Crea una nueva canción
    func create(_ song: SongDTO) throws {
        modelContext.insert(song)
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Actualiza una canción existente
    func update(_ song: SongDTO) throws {
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Elimina una canción por ID
    func delete(_ id: UUID) throws {
        guard let song = try getByID(id) else { return }
        modelContext.delete(song)
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Elimina todas las canciones
    func deleteAll() throws {
        let allSongs = try getAll()
        for song in allSongs {
            modelContext.delete(song)
        }
        try modelContext.save()
        notificationService.notifyChange()
    }

    // MARK: - Batch Operations

    /// Incrementa el contador de reproducciones
    func incrementPlayCount(for id: UUID) throws {
        guard let song = try getByID(id) else { return }
        song.playCount += 1
        song.lastPlayedAt = Date()
        try modelContext.save()
        notificationService.notifyChange()
    }

    /// Actualiza el estado de descarga
    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) throws {
        guard let song = try getByID(id) else { return }
        song.isDownloaded = isDownloaded
        try modelContext.save()
        notificationService.notifyChange()
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
        notificationService.notifyChange()
    }

    // MARK: - Observability

    /// Observa cambios en las canciones
    ///
    /// Uso típico en Repository:
    /// ```swift
    /// localDataSource.observeChanges { dtos in
    ///     let entities = SongMapper.toEntities(dtos)
    ///     onChange(entities)
    /// }
    /// ```
    func observeChanges(onChange: @escaping @MainActor ([SongDTO]) -> Void) {
        notificationService.observe { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let songs = try? self.getAll() {
                    onChange(songs)
                }
            }
        }
    }
}
