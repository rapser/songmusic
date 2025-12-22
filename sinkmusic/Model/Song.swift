
import Foundation
import SwiftData

@Model
final class Song: Identifiable {
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

// MARK: - Helper Extensions
extension Song {
    /// Obtiene la URL local del archivo descargado
    /// Replica la lógica de GoogleDriveService.localURL(for:)
    var localURL: URL? {
        guard isDownloaded else { return nil }

        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let musicDirectory = documentsDirectory.appendingPathComponent("Music")
        let fileURL = musicDirectory.appendingPathComponent("\(id.uuidString).m4a")

        // Verificar que el archivo existe
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return fileURL
    }
}

// MARK: - Hashable
extension Song: Hashable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

