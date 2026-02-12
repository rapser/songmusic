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

    // Relación con canciones (muchos a muchos)
    // SwiftData no garantiza el orden de los arrays en relaciones @Relationship —
    // internamente usa un Set de Core Data. El campo songOrder guarda los UUIDs
    // como "uuid1,uuid2,uuid3" y se usa al leer para restablecer el orden correcto.
    @Relationship(deleteRule: .nullify, inverse: \SongDTO.playlists)
    var songs: [SongDTO]

    /// UUIDs de canciones en orden, separados por coma.
    /// Fuente de verdad para el orden dentro de la playlist.
    var songOrder: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coverImageData: Data? = nil,
        songs: [SongDTO] = []
    ) {
        self.id = id
        self.name = name
        self.desc = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coverImageData = coverImageData
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
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours) h \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}
