//
//  SongRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para operaciones con canciones
/// Define el contrato entre la capa de dominio y la capa de datos
protocol SongRepositoryProtocol: Sendable {

    // MARK: - Query Operations

    /// Obtiene todas las canciones
    func getAll() async throws -> [Song]

    /// Obtiene una canción por ID
    func getByID(_ id: UUID) async throws -> Song?

    /// Obtiene una canción por fileID de Google Drive
    func getByFileID(_ fileID: String) async throws -> Song?

    /// Obtiene canciones descargadas
    func getDownloaded() async throws -> [Song]

    /// Obtiene canciones pendientes de descarga
    func getPending() async throws -> [Song]

    /// Obtiene top canciones por reproducciones
    func getTopSongs(limit: Int) async throws -> [Song]

    // MARK: - Mutation Operations

    /// Crea una nueva canción
    func create(_ song: Song) async throws

    /// Actualiza una canción existente
    func update(_ song: Song) async throws

    /// Elimina una canción
    func delete(_ id: UUID) async throws

    /// Elimina todas las canciones
    func deleteAll() async throws

    // MARK: - Specific Operations

    /// Incrementa el contador de reproducciones
    func incrementPlayCount(for id: UUID) async throws

    /// Actualiza el estado de descarga
    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) async throws

    /// Actualiza metadata de una canción
    func updateMetadata(
        for id: UUID,
        duration: TimeInterval?,
        artworkData: Data?,
        artworkThumbnail: Data?,
        artworkMediumThumbnail: Data?,
        album: String?,
        author: String?
    ) async throws

}
