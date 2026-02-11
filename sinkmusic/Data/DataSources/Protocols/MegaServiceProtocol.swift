//
//  MegaServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation

/// Protocolo que define las capacidades del servicio de Mega
/// Incluye funcionalidad de listado, descarga y desencriptación de archivos
/// Cumple con Dependency Inversion Principle (SOLID)
@MainActor
protocol MegaServiceProtocol: Sendable {

    // MARK: - Fetch Files

    /// Obtiene la lista de archivos de audio de una carpeta pública de Mega
    /// - Parameter folderURL: URL completa de la carpeta (ej: https://mega.nz/folder/xxxxx#yyyyy)
    /// - Returns: Array de archivos encontrados
    func fetchFilesFromFolder(folderURL: String) async throws -> [MegaFile]

    // MARK: - Download

    /// Descarga y desencripta un archivo de Mega
    /// El progreso se emite via EventBus como DownloadEvent.progress
    /// - Parameters:
    ///   - file: Archivo de Mega con su información de desencriptación
    ///   - songID: Identificador de la canción local
    /// - Returns: URL local donde se guardó el archivo desencriptado
    func download(file: MegaFile, songID: UUID) async throws -> URL

    // MARK: - Local File Management

    /// Obtiene la URL local de una canción descargada
    /// - Parameter songID: Identificador de la canción
    /// - Returns: URL local si existe, nil en caso contrario
    func localURL(for songID: UUID) -> URL?

    /// Obtiene la duración de un archivo de audio
    /// - Parameter url: URL del archivo
    /// - Returns: Duración en segundos, nil si falla
    func getDuration(for url: URL) -> TimeInterval?

    /// Elimina el archivo descargado de una canción
    /// - Parameter songID: Identificador de la canción
    func deleteDownload(for songID: UUID) throws
}

// MARK: - Mega Errors

enum MegaError: Error, LocalizedError, Equatable {
    case invalidFolderURL
    case invalidFileKey
    case apiError(String)
    case decryptionFailed
    case downloadFailed(String)
    case fileNotFound
    case rateLimitExceeded(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidFolderURL:
            return "La URL de la carpeta de Mega no es válida"
        case .invalidFileKey:
            return "La clave de desencriptación no es válida"
        case .apiError(let message):
            return "Error de API de Mega: \(message)"
        case .decryptionFailed:
            return "Error al desencriptar el archivo"
        case .downloadFailed(let message):
            return "Error al descargar: \(message)"
        case .fileNotFound:
            return "Archivo no encontrado"
        case .rateLimitExceeded(let seconds):
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                return "Límite de Mega alcanzado (5GB/día). Espera \(hours)h \(minutes)m para continuar."
            } else {
                return "Límite de Mega alcanzado (5GB/día). Espera \(minutes) minutos para continuar."
            }
        }
    }

    /// Tiempo de espera en segundos para reintentar (solo para rateLimitExceeded)
    var retryAfterSeconds: TimeInterval? {
        if case .rateLimitExceeded(let seconds) = self {
            return seconds
        }
        return nil
    }

    /// Verifica si es un error de rate limit
    var isRateLimitError: Bool {
        if case .rateLimitExceeded = self {
            return true
        }
        return false
    }
}
