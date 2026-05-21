//
//  TestFixtures.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

extension Song {
    static func make(
        id: UUID = UUID(),
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String? = nil,
        fileID: String = "file-id",
        isDownloaded: Bool = false,
        duration: TimeInterval? = 180,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        artworkData: Data? = nil
    ) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            author: nil,
            fileID: fileID,
            isDownloaded: isDownloaded,
            duration: duration,
            artworkData: artworkData,
            artworkThumbnail: nil,
            artworkMediumThumbnail: nil,
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            dominantColor: nil
        )
    }
}

extension Playlist {
    static func make(
        id: UUID = UUID(),
        name: String = "Test Playlist",
        description: String = "",
        songs: [Song] = [],
        placeholderColorIndex: Int? = nil
    ) -> Playlist {
        Playlist(
            id: id,
            name: name,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            coverImageData: nil,
            placeholderColorIndex: placeholderColorIndex,
            songs: songs
        )
    }
}

extension CloudFile {
    static func make(
        id: String = UUID().uuidString,
        name: String = "Test Artist - Test Song.m4a",
        provider: CloudFile.CloudProvider = .googleDrive
    ) -> CloudFile {
        CloudFile(
            id: id,
            name: name,
            size: nil,
            mimeType: "audio/m4a",
            downloadURL: nil,
            provider: provider
        )
    }
}
