//
//  CloudFile.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Entidad de dominio que representa un archivo de almacenamiento en la nube
/// Es agnóstico al proveedor específico (Google Drive, OneDrive, Mega, etc.)
struct CloudFile: Identifiable, Sendable {

    /// ID único del archivo
    let id: String

    /// Nombre del archivo
    let name: String

    /// Tamaño del archivo en bytes (opcional)
    let size: Int64?

    /// Tipo MIME del archivo
    let mimeType: String

    /// URL de descarga directa (si está disponible)
    let downloadURL: URL?

    /// Proveedor de almacenamiento
    let provider: CloudProvider

    /// Proveedores de almacenamiento soportados
    enum CloudProvider: String, Sendable {
        case googleDrive
        case oneDrive
        case mega
        case dropbox

        /// Nombre legible para mostrar en UI
        var displayName: String {
            switch self {
            case .googleDrive: return "Google Drive"
            case .oneDrive: return "OneDrive"
            case .mega: return "Mega"
            case .dropbox: return "Dropbox"
            }
        }
    }

    // MARK: - Computed Properties

    /// Verifica si el archivo es un formato de audio soportado
    var isAudioFile: Bool {
        mimeType.hasPrefix("audio/") && (
            name.hasSuffix(".m4a") ||
            name.hasSuffix(".mp3") ||
            name.hasSuffix(".mp4") ||
            name.hasSuffix(".aac")
        )
    }

    /// Extrae el título del nombre del archivo
    /// Asume formato: "Artista - Título.m4a" o solo "Título.m4a"
    var title: String {
        let nameWithoutExtension = name
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".mp4", with: "")
            .replacingOccurrences(of: ".aac", with: "")

        let components = nameWithoutExtension.components(separatedBy: " - ")
        return components.count > 1 ? components[1] : nameWithoutExtension
    }

    /// Extrae el artista del nombre del archivo
    /// Asume formato: "Artista - Título.m4a"
    var artist: String {
        let components = name.components(separatedBy: " - ")
        return components.count > 1 ? components[0] : "Desconocido"
    }

    /// Tamaño formateado en MB
    var formattedSize: String? {
        guard let size = size else { return nil }
        let sizeInMB = Double(size) / (1024 * 1024)
        return String(format: "%.2f MB", sizeInMB)
    }
}

// MARK: - Equatable

extension CloudFile: Equatable {
    static func == (lhs: CloudFile, rhs: CloudFile) -> Bool {
        lhs.id == rhs.id && lhs.provider == rhs.provider
    }
}

// MARK: - Hashable

extension CloudFile: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(provider)
    }
}
