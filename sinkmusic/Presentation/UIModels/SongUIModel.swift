//
//  SongUIModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Modelo de UI para presentar canciones en las vistas
/// Contiene solo datos necesarios para la UI, ya formateados
struct SongUIModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: String // Ya formateado (ej: "03:45")
    let artworkThumbnail: Data?
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
