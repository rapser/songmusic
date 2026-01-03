//
//  SongError.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Errores relacionados con operaciones de canciones
enum SongError: Error {
    case fileNotFound
    case invalidAudioFile
    case downloadFailed(String)
    case metadataExtractionFailed
    case notDownloaded
    case alreadyDownloading
    case invalidURL

    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "Archivo de canción no encontrado"
        case .invalidAudioFile:
            return "El archivo de audio no es válido"
        case .downloadFailed(let message):
            return "Error al descargar: \(message)"
        case .metadataExtractionFailed:
            return "Error al extraer metadatos del archivo"
        case .notDownloaded:
            return "La canción no está descargada"
        case .alreadyDownloading:
            return "La canción ya se está descargando"
        case .invalidURL:
            return "URL de archivo inválida"
        }
    }
}
