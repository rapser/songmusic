//
//  SongUI.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Modelo de UI para presentar canciones en las vistas
/// Contiene solo datos necesarios para la UI, ya formateados
struct SongUI: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: String // Ya formateado (ej: "03:45")
    let durationSeconds: TimeInterval // Duracion en segundos (para PlayerViewModel)
    let artworkThumbnail: Data? // Thumbnail mediano para listas (64x64)
    let artworkSmallThumbnail: Data? // Thumbnail pequeño para Live Activity (32x32)
    let isDownloaded: Bool
    let playCount: Int
    let playCountText: String // Ya formateado (ej: "15 reproducciones")
    let dominantColor: Color?
    let artistAlbumInfo: String // Ya formateado (ej: "Artist • Album")

    // MARK: - Computed Properties para UI

    /// Indica si debe mostrar badge de descargado
    var showDownloadedBadge: Bool {
        isDownloaded
    }

    /// Indica si tiene artwork para mostrar
    var hasArtwork: Bool {
        artworkThumbnail != nil
    }

    /// Color de fondo derivado del artwork o default
    var backgroundColor: Color {
        dominantColor ?? Color.appPurple
    }
}
