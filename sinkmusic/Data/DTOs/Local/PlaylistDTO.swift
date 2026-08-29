//
//  PlaylistDTO.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Migrated to DTO on 3/01/26.
//

import Foundation
import SwiftData

/// DTO (Data Transfer Object) para SwiftData - Capa de persistencia
@Model
final class PlaylistDTO {
    var id: UUID
    var name: String
    var desc: String
    var createdAt: Date
    var updatedAt: Date
    var coverImageData: Data?
    /// Índice del color del placeholder (0 a N-1). nil = usar color por id.
    var placeholderColorIndex: Int?

    // Relación con canciones (muchos a muchos). SwiftData no garantiza el orden de los
    // arrays en relaciones @Relationship — el orden manual vive ahora en `PlaylistItemDTO`.
    @Relationship(deleteRule: .nullify, inverse: \SongDTO.playlists)
    var songs: [SongDTO]

    /// **Legacy.** Antes era la fuente de verdad del orden (CSV "uuid1,uuid2,..."). Sustituido
    /// por `PlaylistItemDTO` (hallazgo N). Se conserva la columna solo como fuente del backfill
    /// perezoso en `PlaylistLocalDataSource` y para no forzar una migración destructiva; ya no
    /// se escribe ni se lee fuera de ese backfill.
    var songOrder: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coverImageData: Data? = nil,
        placeholderColorIndex: Int? = nil,
        songs: [SongDTO] = []
    ) {
        self.id = id
        self.name = name
        self.desc = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coverImageData = coverImageData
        self.placeholderColorIndex = placeholderColorIndex
        self.songs = songs
        self.songOrder = songs.map { $0.id.uuidString }.joined(separator: ",")
    }

    var songCount: Int {
        songs.count
    }

    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    var formattedDuration: String {
        DurationFormatter.hoursMinutes(totalDuration, style: .spaced)
    }
}
