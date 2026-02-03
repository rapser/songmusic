//
//  Song.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Representa un color RGB como tipo de dominio puro (sin dependencia de SwiftUI)
struct RGBColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

/// Entidad de dominio PURA - Sin dependencia de SwiftData ni SwiftUI
/// Representa una canción en la lógica de negocio
struct Song: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String?
    let author: String?
    let fileID: String
    let isDownloaded: Bool
    let duration: TimeInterval?
    let artworkData: Data?
    let artworkThumbnail: Data?
    let artworkMediumThumbnail: Data?
    let playCount: Int
    let lastPlayedAt: Date?

    /// Color dominante derivado de artwork (componentes RGB puros)
    let dominantColor: RGBColor?

    // MARK: - Computed Properties (Lógica de Dominio)

    /// URL local del archivo descargado
    var localURL: URL? {
        guard isDownloaded else { return nil }

        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let musicDirectory = documentsDirectory.appendingPathComponent("Music")
        let fileURL = musicDirectory.appendingPathComponent("\(id.uuidString).m4a")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return fileURL
    }

    /// Duración formateada (mm:ss)
    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Información del artista y álbum para UI
    var artistAlbumInfo: String {
        if let album = album, !album.isEmpty {
            return "\(artist) • \(album)"
        }
        return artist
    }

    /// Indica si la canción ha sido reproducida alguna vez
    var hasBeenPlayed: Bool {
        playCount > 0
    }

    /// Texto descriptivo del contador de reproducciones
    var playCountText: String {
        switch playCount {
        case 0:
            return "Sin reproducir"
        case 1:
            return "1 reproducción"
        default:
            return "\(playCount) reproducciones"
        }
    }
}
