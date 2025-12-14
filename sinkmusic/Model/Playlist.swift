//
//  Playlist.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID
    var name: String
    var desc: String
    var createdAt: Date
    var updatedAt: Date
    var coverImageData: Data?

    // Relación con canciones (muchos a muchos)
    @Relationship(deleteRule: .nullify, inverse: \Song.playlists)
    var songs: [Song]

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coverImageData: Data? = nil,
        songs: [Song] = []
    ) {
        self.id = id
        self.name = name
        self.desc = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coverImageData = coverImageData
        self.songs = songs
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
