//
//  PlaylistUIModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Modelo de UI para presentar playlists en las vistas
/// Contiene solo datos necesarios para la UI, ya formateados
struct PlaylistUIModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let songCount: Int
    let formattedDuration: String // Ya formateado (ej: "2 h 35 min")
    let displayInfo: String // Ya formateado (ej: "15 canciones • 1 h 20 min")
    let coverImageData: Data?
    let songs: [SongUIModel]
    let downloadProgress: Double // 0.0 a 1.0
    let isEmpty: Bool

    // MARK: - Computed Properties para UI

    /// Indica si debe mostrar cover image
    var hasCoverImage: Bool {
        coverImageData != nil
    }

    /// Texto descriptivo del número de canciones
    var songCountText: String {
        songCount == 1 ? "1 canción" : "\(songCount) canciones"
    }

    /// Indica si todas las canciones están descargadas
    var isFullyDownloaded: Bool {
        downloadProgress >= 1.0 && !isEmpty
    }

    /// Indica si hay canciones sin descargar
    var hasPendingDownloads: Bool {
        downloadProgress < 1.0 && !isEmpty
    }

    /// Porcentaje formateado
    var downloadProgressText: String {
        let percentage = Int(downloadProgress * 100)
        return "\(percentage)%"
    }
}
