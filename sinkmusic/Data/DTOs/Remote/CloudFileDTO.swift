//
//  CloudFileDTO.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer - Remote DTO
//

import Foundation

/// DTO para archivos de servicios cloud (Google Drive, OneDrive, Mega, etc.)
/// Representa la estructura de datos que viene de APIs de almacenamiento en la nube
struct CloudFileDTO: Codable, Sendable {

    /// ID único del archivo en el servicio cloud
    let id: String

    /// Nombre del archivo
    let name: String

    /// Tamaño del archivo en bytes
    let size: Int64?

    /// Tipo MIME del archivo (audio/mpeg, audio/mp4, audio/x-m4a)
    let mimeType: String

    /// URL de descarga directa (si está disponible)
    let downloadURL: String?

    /// Proveedor de almacenamiento en la nube
    let provider: CloudProvider

    /// Proveedores de almacenamiento soportados
    enum CloudProvider: String, Codable, Sendable {
        case googleDrive = "google_drive"
        case oneDrive = "one_drive"
        case mega = "mega"
        case dropbox = "dropbox"
    }
}

/// DTO específico para respuestas de Google Drive API
struct GoogleDriveResponse: Codable, Sendable {
    let files: [GoogleDriveFile]
    let nextPageToken: String?
}

/// DTO para archivos individuales de Google Drive
struct GoogleDriveFile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let mimeType: String

    /// Extrae el título del nombre del archivo
    /// Asume formato: "Artista - Título.m4a"
    var title: String {
        let components = name.components(separatedBy: " - ")
        return components.count > 1 ? components[1].replacingOccurrences(of: ".m4a", with: "") : name
    }

    /// Extrae el artista del nombre del archivo
    /// Asume formato: "Artista - Título.m4a"
    var artist: String {
        let components = name.components(separatedBy: " - ")
        return components.first ?? "Artista Desconocido"
    }
}

// MARK: - Mapper Extensions

extension CloudFileDTO {
    /// Crea CloudFileDTO desde GoogleDriveFile
    static func from(googleDriveFile: GoogleDriveFile) -> CloudFileDTO {
        CloudFileDTO(
            id: googleDriveFile.id,
            name: googleDriveFile.name,
            size: nil, // Google Drive API no devuelve tamaño en listado básico
            mimeType: googleDriveFile.mimeType,
            downloadURL: nil,
            provider: .googleDrive
        )
    }
}
