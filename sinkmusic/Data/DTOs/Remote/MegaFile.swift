//
//  MegaFile.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer - Remote DTO
//

import Foundation

/// DTO para archivos de Mega
/// Contiene información del archivo y la clave de desencriptación
struct MegaFile: Codable, Identifiable, Sendable, Hashable {
    private static let supportedAudioExtensions = [".m4a", ".mp3", ".mp4", ".aac", ".flac", ".wav", ".ogg"]

    /// ID único del archivo en Mega (nodeId/handle)
    let id: String

    /// Nombre del archivo (ya desencriptado)
    let name: String

    /// Tamaño del archivo en bytes
    let size: Int64?

    /// Clave de desencriptación del archivo (derivada de la clave de la carpeta)
    let decryptionKey: String

    /// ID del nodo padre (carpeta)
    let parentId: String?

    // MARK: - Computed Properties

    /// Extrae el título del nombre del archivo
    /// Asume formato: "Artista - Título.ext" o solo "Título.ext"
    var title: String {
        let nameWithoutExtension = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent

        let components = nameWithoutExtension.components(separatedBy: " - ")
        return components.count > 1 ? components[1] : nameWithoutExtension
    }

    /// Extrae el artista del nombre del archivo
    /// Asume formato: "Artista - Título.ext"
    var artist: String {
        let components = name.components(separatedBy: " - ")
        return components.count > 1 ? components[0] : "Artista Desconocido"
    }

    /// Verifica si es un archivo de audio soportado
    var isAudioFile: Bool {
        let lowercaseName = name.lowercased()
        return MegaFile.supportedAudioExtensions.contains { lowercaseName.hasSuffix($0) }
    }

    /// Tamaño formateado en MB
    var formattedSize: String? {
        guard let size = size else { return nil }
        let sizeInMB = Double(size) / (1024 * 1024)
        return String(format: "%.2f MB", sizeInMB)
    }

    /// MIME type inferido del nombre
    var mimeType: String {
        let lowercaseName = name.lowercased()
        if lowercaseName.hasSuffix(".m4a") || lowercaseName.hasSuffix(".mp4") {
            return "audio/mp4"
        } else if lowercaseName.hasSuffix(".mp3") {
            return "audio/mpeg"
        } else if lowercaseName.hasSuffix(".aac") {
            return "audio/aac"
        } else if lowercaseName.hasSuffix(".flac") {
            return "audio/flac"
        } else if lowercaseName.hasSuffix(".wav") {
            return "audio/wav"
        } else if lowercaseName.hasSuffix(".ogg") {
            return "audio/ogg"
        }
        return "audio/unknown"
    }
}

// MARK: - Mega API Response DTOs

/// Respuesta del API de Mega para listado de carpetas
struct MegaFolderResponse: Codable, Sendable {
    let f: [MegaNode]?      // Lista de nodos (archivos/carpetas)
    let ok: [MegaOwnerKey]? // Claves del propietario
    let s: [MegaShare]?     // Información de compartido
    let u: [MegaUser]?      // Usuarios
    let sn: String?         // Sequence number
}

/// Nodo de Mega (puede ser archivo o carpeta)
struct MegaNode: Codable, Sendable {
    let h: String           // Handle (ID)
    let p: String?          // Parent handle
    let u: String?          // User handle
    let t: Int              // Tipo: 0=archivo, 1=carpeta, 2=root, 3=inbox, 4=trash
    let a: String?          // Atributos encriptados (nombre, etc.)
    let k: String?          // Clave encriptada
    let s: Int64?           // Tamaño (solo para archivos)
    let ts: Int64?          // Timestamp
    let fa: String?         // File attributes (thumbnail, etc.)
}

/// Clave del propietario
struct MegaOwnerKey: Codable, Sendable {
    let h: String   // Handle
    let k: String   // Key
}

/// Información de compartido
struct MegaShare: Codable, Sendable {
    let h: String?  // Handle
    let r: Int?     // Rights
    let u: String?  // User
}

/// Usuario de Mega
struct MegaUser: Codable, Sendable {
    let u: String   // User ID
    let c: Int?     // Contact type
    let m: String?  // Email
}

// MARK: - Mapper Extensions

extension CloudFileDTO {
    /// Crea CloudFileDTO desde MegaFile
    static func from(megaFile: MegaFile) -> CloudFileDTO {
        CloudFileDTO(
            id: megaFile.id,
            name: megaFile.name,
            size: megaFile.size,
            mimeType: megaFile.mimeType,
            downloadURL: nil, // Mega requiere API call para URL de descarga
            provider: .mega
        )
    }
}
