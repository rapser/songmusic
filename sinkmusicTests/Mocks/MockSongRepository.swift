//
//  MockSongRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockSongRepository: SongRepositoryProtocol {

    var songs: [Song] = []

    var createCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var incrementPlayCountCallCount = 0
    var lastDeletedID: UUID?
    var lastUpdatedSong: Song?
    var lastCreatedSong: Song?

    var shouldThrowOnCreate = false
    var shouldThrowOnUpdate = false
    var shouldThrowOnDelete = false

    func getAll() async throws -> [Song] { songs }

    func getByID(_ id: UUID) async throws -> Song? {
        songs.first { $0.id == id }
    }

    func getByFileID(_ fileID: String) async throws -> Song? {
        songs.first { $0.fileID == fileID }
    }

    func getDownloaded() async throws -> [Song] {
        songs.filter { $0.isDownloaded }
    }

    func getPending() async throws -> [Song] {
        songs.filter { !$0.isDownloaded }
    }

    func getTopSongs(limit: Int) async throws -> [Song] {
        Array(songs.filter { $0.playCount > 0 }.sorted { $0.playCount > $1.playCount }.prefix(limit))
    }

    func getRecentlyPlayed(limit: Int) async throws -> [Song] {
        Array(
            songs
                .filter { $0.lastPlayedAt != nil }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(limit)
        )
    }

    func search(query: String) async throws -> [Song] {
        guard !query.isEmpty else { return songs }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    func searchByAlbum(query: String) async throws -> [Song] {
        guard !query.isEmpty else { return [] }
        return songs.filter { $0.album?.localizedCaseInsensitiveContains(query) ?? false }
    }

    func create(_ song: Song) async throws {
        if shouldThrowOnCreate { throw SongError.fileNotFound }
        createCallCount += 1
        lastCreatedSong = song
        songs.append(song)
    }

    func update(_ song: Song) async throws {
        if shouldThrowOnUpdate { throw SongError.fileNotFound }
        updateCallCount += 1
        lastUpdatedSong = song
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index] = song
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowOnDelete { throw SongError.fileNotFound }
        deleteCallCount += 1
        lastDeletedID = id
        songs.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        songs.removeAll()
    }

    func incrementPlayCount(for id: UUID) async throws {
        incrementPlayCountCallCount += 1
        guard let index = songs.firstIndex(where: { $0.id == id }) else { return }
        let s = songs[index]
        songs[index] = Song(
            id: s.id, title: s.title, artist: s.artist, album: s.album,
            author: s.author, fileID: s.fileID, isDownloaded: s.isDownloaded,
            duration: s.duration, artworkData: s.artworkData,
            artworkThumbnail: s.artworkThumbnail, artworkMediumThumbnail: s.artworkMediumThumbnail,
            playCount: s.playCount + 1, lastPlayedAt: Date(), dominantColor: s.dominantColor
        )
    }

    func updateDownloadStatus(for id: UUID, isDownloaded: Bool) async throws {
        guard let index = songs.firstIndex(where: { $0.id == id }) else { return }
        let s = songs[index]
        songs[index] = Song(
            id: s.id, title: s.title, artist: s.artist, album: s.album,
            author: s.author, fileID: s.fileID, isDownloaded: isDownloaded,
            duration: s.duration, artworkData: s.artworkData,
            artworkThumbnail: s.artworkThumbnail, artworkMediumThumbnail: s.artworkMediumThumbnail,
            playCount: s.playCount, lastPlayedAt: s.lastPlayedAt, dominantColor: s.dominantColor
        )
    }

    func updateMetadata(
        for id: UUID,
        duration: TimeInterval?,
        artworkData: Data?,
        artworkThumbnail: Data?,
        artworkMediumThumbnail: Data?,
        album: String?,
        author: String?
    ) async throws {
        guard let index = songs.firstIndex(where: { $0.id == id }) else { return }
        let s = songs[index]
        songs[index] = Song(
            id: s.id, title: s.title, artist: s.artist,
            album: album ?? s.album, author: author ?? s.author,
            fileID: s.fileID, isDownloaded: s.isDownloaded,
            duration: duration ?? s.duration, artworkData: artworkData ?? s.artworkData,
            artworkThumbnail: artworkThumbnail ?? s.artworkThumbnail,
            artworkMediumThumbnail: artworkMediumThumbnail ?? s.artworkMediumThumbnail,
            playCount: s.playCount, lastPlayedAt: s.lastPlayedAt, dominantColor: s.dominantColor
        )
    }
}
