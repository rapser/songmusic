//
//  MockPlaylistReadStore.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockPlaylistReadStore: PlaylistReadStoreProtocol {

    var playlistsValue: [Playlist] = []
    var songsInPlaylistValue: [Song] = []
    var statsValue: PlaylistStats = PlaylistStats(songCount: 0, totalDuration: 0, totalPlays: 0, downloadedSongs: 0)

    private var continuation: AsyncStream<Void>.Continuation?
    private lazy var stream: AsyncStream<Void> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init() {
        _ = stream
    }

    func allPlaylists() async throws -> [Playlist] { playlistsValue }
    func songs(inPlaylist id: UUID) async throws -> [Song] { songsInPlaylistValue }
    func stats(forPlaylist id: UUID) async throws -> PlaylistStats { statsValue }

    func changes() -> AsyncStream<Void> { stream }

    /// Simula que algo relevante cambió, para que el ViewModel bajo test recargue.
    func simulateChange() {
        continuation?.yield(())
    }
}
