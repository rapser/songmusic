//
//  AppError.swift
//  sinkmusic
//
//  Created by Refactoring
//

import Foundation

/// Errores personalizados de la aplicación
enum AppError: LocalizedError {
    case network(NetworkError)
    case audio(AudioError)
    case storage(StorageError)
    case data(DataError)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.errorDescription
        case .audio(let error):
            return error.errorDescription
        case .storage(let error):
            return error.errorDescription
        case .data(let error):
            return error.errorDescription
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case unauthorized
    case notFound
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .requestFailed(let error):
            return "Error en la petición: \(error.localizedDescription)"
        case .invalidResponse:
            return "Respuesta del servidor inválida"
        case .decodingFailed(let error):
            return "Error al decodificar datos: \(error.localizedDescription)"
        case .unauthorized:
            return "No autorizado"
        case .notFound:
            return "Recurso no encontrado"
        case .serverError(let code):
            return "Error del servidor: \(code)"
        }
    }
}

// MARK: - Audio Errors
enum AudioError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case playbackFailed(Error)
    case audioSessionFailed(Error)
    case engineNotRunning
    case fileLoadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Archivo de audio no encontrado"
        case .invalidFormat:
            return "Formato de audio no soportado"
        case .playbackFailed(let error):
            return "Error al reproducir: \(error.localizedDescription)"
        case .audioSessionFailed(let error):
            return "Error en la sesión de audio: \(error.localizedDescription)"
        case .engineNotRunning:
            return "El motor de audio no está funcionando"
        case .fileLoadFailed(let error):
            return "Error al cargar archivo: \(error.localizedDescription)"
        }
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case directoryCreationFailed
    case fileNotFound
    case fileDeletionFailed(Error)
    case fileMoveFailed(Error)
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "No se pudo crear el directorio"
        case .fileNotFound:
            return "Archivo no encontrado"
        case .fileDeletionFailed(let error):
            return "Error al eliminar archivo: \(error.localizedDescription)"
        case .fileMoveFailed(let error):
            return "Error al mover archivo: \(error.localizedDescription)"
        case .insufficientSpace:
            return "Espacio insuficiente en el dispositivo"
        }
    }
}

// MARK: - Data Errors
enum DataError: LocalizedError {
    case fetchFailed(Error)
    case saveFailed(Error)
    case deleteFailed(Error)
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Error al obtener datos: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Error al guardar: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Error al eliminar: \(error.localizedDescription)"
        case .notFound:
            return "Datos no encontrados"
        case .invalidData:
            return "Datos inválidos"
        }
    }
}
