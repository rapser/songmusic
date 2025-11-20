
import Foundation
import SwiftData

@Model
final class Song: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var fileID: String
    var isDownloaded: Bool
    var duration: TimeInterval?

    // Relación con playlists (muchos a muchos)
    var playlists: [Playlist] = []

    init(id: UUID = UUID(), title: String, artist: String, fileID: String, isDownloaded: Bool = false, duration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileID = fileID
        self.isDownloaded = isDownloaded
        self.duration = duration
    }
}

