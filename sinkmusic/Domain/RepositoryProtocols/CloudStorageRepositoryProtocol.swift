//
//  CloudStorageRepositoryProtocol.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Protocolo de repositorio para almacenamiento en la nube
/// Abstrae cualquier servicio de almacenamiento (Google Drive, OneDrive, Mega, etc.)
protocol CloudStorageRepositoryProtocol: Sendable {

    // MARK: - Remote Operations

    /// Obtiene lista de archivos de música desde el servicio cloud
    func fetchSongsFromFolder() async throws -> [CloudFileEntity]

    /// Descarga un archivo desde el servicio cloud
    func download(
        fileID: String,
        songID: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL

    /// Obtiene la duración de un archivo de audio local
    @MainActor func getDuration(for url: URL) -> TimeInterval?

    /// Elimina el archivo descargado localmente
    @MainActor func deleteDownload(for songID: UUID) throws

    /// Obtiene la URL local de un archivo descargado
    @MainActor func localURL(for songID: UUID) -> URL?
}

/// Errores de almacenamiento en la nube
enum CloudStorageError: Error {
    case credentialsNotConfigured
    case missingAPIKey
    case missingFolderId
    case unsupportedProvider
    case downloadFailed(Error)
    case invalidFile
}
