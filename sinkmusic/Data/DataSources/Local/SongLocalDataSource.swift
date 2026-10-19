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

    // Nota: el ranking "Canciones que más escuchas" de Inicio NO se calcula aquí.
    // Usa un contador con ventana de 7 días que vive fuera de SwiftData
    // (`RankingWindowRepository`), combinado con `getDownloaded()` en `SongRepositoryImpl`.

    /// Canciones descargadas de entre un conjunto concreto de ids.
    ///
    /// La usa "Recientes": el orden lo da `SongPlayStatsDTO` y aquí solo se resuelven esos
    /// ids, así que la consulta la acota el número de canciones *escuchadas* y no el tamaño
    /// de la biblioteca.
    func getDownloaded(ids: [UUID]) throws -> [SongDTO] {
        let descriptor = FetchDescriptor<SongDTO>(
            predicate: #Predicate { ids.contains($0.id) && $0.isDownloaded }
        )
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

    /// Busca canciones cuyo álbum contenga `query`.
    ///
    /// Excepción aceptada: se filtra en memoria en vez de con `#Predicate`. `album` es
    /// opcional y SwiftData/CoreData no sabe generar SQL para `CONTAINS[cd]` sobre una
    /// columna opcional (ni con `$0.album!`, ni con `$0.album ?? ""`, ni con encadenado
    /// opcional). El pre-filtro `album != nil` sí es expresable y acota la carga a las
    /// canciones que tienen álbum antes de hacer el `contains` real.
    func searchByAlbum(query: String) throws -> [SongDTO] {
        let withAlbum = try modelContext.fetch(
            FetchDescriptor<SongDTO>(
                predicate: #Predicate { $0.album != nil },
                sortBy: [SortDescriptor(\SongDTO.title)]
            )
        )
        return withAlbum.filter { $0.album?.localizedStandardContains(query) ?? false }
    }

    /// Crea una nueva canción
    func create(_ song: SongDTO) throws {
        modelContext.insert(song)
        try modelContext.save()
    }

    /// Crea varias canciones y persiste todo en un solo `save()`.
    func create(_ songs: [SongDTO]) throws {
        guard !songs.isEmpty else { return }

        for song in songs {
            modelContext.insert(song)
        }

        try modelContext.save()
    }

    /// Actualiza una canción existente copiando los campos del DTO recibido al persistido.
    func update(_ song: SongDTO) throws {
        guard let existing = try getByID(song.id) else { return }
        existing.apply(from: song)
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

    // Nota: las reproducciones (`playCount`, `lastPlayedAt`) ya no se escriben aquí. Viven
    // en `SongPlayStatsDTO` y las gestiona `SongPlayStatsLocalDataSource`, para que dar al
    // play no toque la fila de la canción — que es lo que vigilan las cuatro tiendas del
    // read-side. Los campos siguen en `SongDTO` como semilla del backfill.

    /// Actualiza el estado de descarga
    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) throws {
        guard let song = try getByID(id) else { return }
        song.isDownloaded = isDownloaded
        try modelContext.save()
    }


}
