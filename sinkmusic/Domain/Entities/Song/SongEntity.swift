//
//  SongEntity.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Entidad de dominio PURA - Sin dependencia de SwiftData
/// Representa una canción en la lógica de negocio
struct SongEntity: Identifiable, Hashable, Sendable {
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

    // Dominant color derivado de artwork (para UI)
    let dominantColor: Color?

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

// MARK: - Inicializador Conveniente

extension SongEntity {
    /// Inicializador con valores por defecto
    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String? = nil,
        author: String? = nil,
        fileID: String,
        isDownloaded: Bool = false,
        duration: TimeInterval? = nil,
        artworkData: Data? = nil,
        artworkThumbnail: Data? = nil,
        artworkMediumThumbnail: Data? = nil,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        dominantColor: Color? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.author = author
        self.fileID = fileID
        self.isDownloaded = isDownloaded
        self.duration = duration
        self.artworkData = artworkData
        self.artworkThumbnail = artworkThumbnail
        self.artworkMediumThumbnail = artworkMediumThumbnail
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.dominantColor = dominantColor
    }
}
