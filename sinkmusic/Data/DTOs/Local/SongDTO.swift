//
//  SongDTO.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Migrated to DTO on 3/01/26.
//

import Foundation
import SwiftData

/// DTO (Data Transfer Object) para SwiftData - Capa de persistencia
@Model
final class SongDTO: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String?
    var author: String?
    @Attribute(.unique) var fileID: String
    var isDownloaded: Bool
    var duration: TimeInterval?
    var artworkData: Data?
    var artworkThumbnail: Data? // Thumbnail pequeño para Live Activities (32x32, < 1KB)
    var artworkMediumThumbnail: Data? // Thumbnail medio para listas (64x64, < 5KB)

    var cachedDominantColorRed: Double?
    var cachedDominantColorGreen: Double?
    var cachedDominantColorBlue: Double?

    // Contador de reproducciones
    var playCount: Int = 0
    var lastPlayedAt: Date?

    // Relación con playlists (muchos a muchos)
    var playlists: [PlaylistDTO] = []

    init(id: UUID = UUID(), title: String, artist: String, album: String? = nil, author: String? = nil, fileID: String, isDownloaded: Bool = false, duration: TimeInterval? = nil, artworkData: Data? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.author = author
        self.fileID = fileID
        self.isDownloaded = isDownloaded
        self.duration = duration
        self.artworkData = artworkData
    }
}

// MARK: - Mutación
extension SongDTO {
    /// Copia todos los campos mutables desde otro DTO (menos `id` y la relación `playlists`,
    /// que se gestionan aparte). Único punto de verdad del copiado para `update()`:
    /// añadir un campo nuevo al modelo = tocar solo aquí.
    func apply(from other: SongDTO) {
        title = other.title
        artist = other.artist
        album = other.album
        author = other.author
        fileID = other.fileID
        isDownloaded = other.isDownloaded
        duration = other.duration
        artworkData = other.artworkData
        artworkThumbnail = other.artworkThumbnail
        artworkMediumThumbnail = other.artworkMediumThumbnail
        cachedDominantColorRed = other.cachedDominantColorRed
        cachedDominantColorGreen = other.cachedDominantColorGreen
        cachedDominantColorBlue = other.cachedDominantColorBlue
        playCount = other.playCount
        lastPlayedAt = other.lastPlayedAt
    }
}

// MARK: - Hashable
extension SongDTO: Hashable {
    static func == (lhs: SongDTO, rhs: SongDTO) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

