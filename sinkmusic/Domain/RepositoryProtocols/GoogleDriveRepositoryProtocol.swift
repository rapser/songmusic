//
//  GoogleDriveRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para Google Drive
/// Abstrae GoogleDriveService de la capa de dominio
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
    func getDuration(for url: URL) -> TimeInterval?

    /// Elimina el archivo descargado localmente
    func deleteDownload(for songID: UUID) throws

    /// Obtiene la URL local de una canción descargada
    func localURL(for songID: UUID) -> URL?
}

/// Estructura para archivos de Google Drive
struct GoogleDriveFile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let mimeType: String

    var title: String {
        let components = name.components(separatedBy: " - ")
        return components.count > 1 ? components[1].replacingOccurrences(of: ".m4a", with: "") : name
    }

    var artist: String {
        let components = name.components(separatedBy: " - ")
        return components.first ?? "Artista Desconocido"
    }
}

/// Respuesta de Google Drive API
struct GoogleDriveResponse: Codable {
    let files: [GoogleDriveFile]
    let nextPageToken: String?
}

/// Errores de Google Drive
enum GoogleDriveError: Error {
    case credentialsNotConfigured
    case missingAPIKey
    case missingFolderId
}
