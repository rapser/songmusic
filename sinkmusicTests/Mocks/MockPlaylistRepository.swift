//
//  MockPlaylistRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockPlaylistRepository: PlaylistRepositoryProtocol {

    var playlists: [Playlist] = []

    var createCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var addSongCallCount = 0
    var removeSongCallCount = 0
    var updateSongsOrderCallCount = 0
    var lastUpdatedSongsOrder: [UUID]?

    var shouldThrowOnCreate = false

    func getAll() async throws -> [Playlist] { playlists }

    func getByID(_ id: UUID) async throws -> Playlist? {
        playlists.first { $0.id == id }
    }

    func create(_ playlist: Playlist) async throws -> Playlist {
        if shouldThrowOnCreate { throw PlaylistError.invalidOperation("mock error") }
        createCallCount += 1
        playlists.append(playlist)
        return playlist
    }

    func update(_ playlist: Playlist) async throws {
        updateCallCount += 1
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
        }
    }

    func delete(_ id: UUID) async throws {
        deleteCallCount += 1
        playlists.removeAll { $0.id == id }
    }

    func addSong(songID: UUID, toPlaylist playlistID: UUID) async throws {
        addSongCallCount += 1
    }

    func removeSong(songID: UUID, fromPlaylist playlistID: UUID) async throws {
        removeSongCallCount += 1
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let p = playlists[index]
        playlists[index] = Playlist(
            id: p.id, name: p.name, description: p.description,
            createdAt: p.createdAt, updatedAt: Date(),
            coverImageData: p.coverImageData, placeholderColorIndex: p.placeholderColorIndex,
            songs: p.songs.filter { $0.id != songID }
        )
    }

    func updateSongsOrder(playlistID: UUID, songIDs: [UUID]) async throws {
        updateSongsOrderCallCount += 1
        lastUpdatedSongsOrder = songIDs
    }
}
