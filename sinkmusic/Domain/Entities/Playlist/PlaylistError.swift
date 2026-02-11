//
//  PlaylistError.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Errores relacionados con operaciones de playlists
enum PlaylistError: Error {
    case notFound
    case songAlreadyExists
    case songNotFound
    case emptyName
    case invalidOperation(String)

    var localizedDescription: String {
        switch self {
        case .notFound:
            return "Playlist no encontrada"
        case .songAlreadyExists:
            return "La canción ya existe en la playlist"
        case .songNotFound:
            return "Canción no encontrada en la playlist"
        case .emptyName:
            return "El nombre de la playlist no puede estar vacío"
        case .invalidOperation(let message):
            return "Operación inválida: \(message)"
        }
    }
}
