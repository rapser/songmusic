//
//  SyncError.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import Foundation

enum SyncError: Error, Equatable {
    case invalidCredentials
    case emptyFolder
    case networkError(String)
    case invalidAudioFile

    /// Texto listo para mostrar al usuario.
    var userMessage: String {
        switch self {
        case .invalidCredentials:
            return "Las credenciales son inválidas o han expirado"
        case .emptyFolder:
            return "No se encontró la carpeta o no contiene archivos de audio"
        case .networkError(let detail):
            return "Error de conexión: \(detail)"
        case .invalidAudioFile:
            return "El archivo de audio descargado no es válido"
        }
    }
}
