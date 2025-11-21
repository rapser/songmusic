
import Foundation
import SwiftData

@Model
final class Song: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String?
    var author: String?
    var fileID: String
    var isDownloaded: Bool
    var duration: TimeInterval?
    var artworkData: Data?

    // Relación con playlists (muchos a muchos)
    var playlists: [Playlist] = []

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

