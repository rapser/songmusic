//
//  GoogleDriveRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//
// DEPRECATED: Usar CloudStorageRepositoryProtocol en su lugar
//

import Foundation

/// Protocolo de repositorio para Google Drive
/// Abstrae GoogleDriveService de la capa de dominio
/// DEPRECATED: Usar CloudStorageRepositoryProtocol en su lugar
protocol GoogleDriveRepositoryProtocol: Sendable {

    // MARK: - Remote Operations

    /// Obtiene lista de archivos de música desde Google Drive
    func fetchSongsFromFolder() async throws -> [GoogleDriveFile]

    /// Descarga una canción desde Google Drive
    func download(
        fileID: String,
        songID: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL

    /// Obtiene la duración de un archivo de audio local
    @MainActor func getDuration(for url: URL) -> TimeInterval?

    /// Elimina el archivo descargado localmente
    @MainActor func deleteDownload(for songID: UUID) throws

    /// Obtiene la URL local de una canción descargada
    @MainActor func localURL(for songID: UUID) -> URL?
}

/// Errores de Google Drive
enum GoogleDriveError: Error {
    case credentialsNotConfigured
    case missingAPIKey
    case missingFolderId
}
