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

    /// Duración formateada (mm:ss)
    var formattedDuration: String {
        DurationFormatter.clock(duration)
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

// MARK: - Copias con cambios

extension Song {

    /// Devuelve una copia cambiando solo los campos indicados.
    /// Un argumento `nil` significa "no tocar este campo" — para *vaciar* un campo opcional
    /// (artwork, color) usar `clearingLocalArtwork()`.
    func with(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        author: String? = nil,
        isDownloaded: Bool? = nil,
        duration: TimeInterval? = nil,
        playCount: Int? = nil,
        lastPlayedAt: Date? = nil,
        dominantColor: RGBColor? = nil
    ) -> Song {
        Song(
            id: id,
            title: title ?? self.title,
            artist: artist ?? self.artist,
            album: album ?? self.album,
            author: author ?? self.author,
            fileID: fileID,
            isDownloaded: isDownloaded ?? self.isDownloaded,
            duration: duration ?? self.duration,
            artworkData: artworkData,
            artworkThumbnail: artworkThumbnail,
            artworkMediumThumbnail: artworkMediumThumbnail,
            playCount: playCount ?? self.playCount,
            lastPlayedAt: lastPlayedAt ?? self.lastPlayedAt,
            dominantColor: dominantColor ?? self.dominantColor
        )
    }

    /// Copia sin artwork ni color dominante en local (se conserva `isDownloaded`).
    func clearingLocalArtwork() -> Song {
        Song(
            id: id, title: title, artist: artist, album: album, author: author,
            fileID: fileID, isDownloaded: isDownloaded, duration: duration,
            artworkData: nil, artworkThumbnail: nil, artworkMediumThumbnail: nil,
            playCount: playCount, lastPlayedAt: lastPlayedAt, dominantColor: nil
        )
    }
}
