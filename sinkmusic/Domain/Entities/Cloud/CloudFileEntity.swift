//
//  CloudFileEntity.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Entidad de dominio que representa un archivo de almacenamiento en la nube
/// Es agnóstico al proveedor específico (Google Drive, OneDrive, Mega, etc.)
struct CloudFileEntity: Identifiable, Sendable {

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

    /// Tamaño formateado en MB
    var formattedSize: String? {
        guard let size = size else { return nil }
        let sizeInMB = Double(size) / (1024 * 1024)
        return String(format: "%.2f MB", sizeInMB)
    }
}

// MARK: - Equatable

extension CloudFileEntity: Equatable {
    static func == (lhs: CloudFileEntity, rhs: CloudFileEntity) -> Bool {
        lhs.id == rhs.id && lhs.provider == rhs.provider
    }
}

// MARK: - Hashable

extension CloudFileEntity: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(provider)
    }
}
