//
//  MockHomeReadStore.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockHomeReadStore: HomeReadStoreProtocol {

    var playlistsValue: [Playlist] = []
    var mostPlayedPlaylistsValue: [Playlist] = []
    var recentlyPlayedSongsValue: [Song] = []
    var mostPlayedSongsValue: [Song] = []
    var downloadedSongsValue: [Song] = []

    private var continuation: AsyncStream<Void>.Continuation?
    private lazy var stream: AsyncStream<Void> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init() {
        _ = stream
    }

    func playlists() async throws -> [Playlist] { playlistsValue }
    func mostPlayedPlaylists(limit: Int) async throws -> [Playlist] { Array(mostPlayedPlaylistsValue.prefix(limit)) }
    func recentlyPlayedSongs(limit: Int) async throws -> [Song] { Array(recentlyPlayedSongsValue.prefix(limit)) }
    func mostPlayedSongs(limit: Int) async throws -> [Song] { Array(mostPlayedSongsValue.prefix(limit)) }
    func downloadedSongs() async throws -> [Song] { downloadedSongsValue }

    func changes() -> AsyncStream<Void> { stream }

    /// Simula que algo relevante cambió, para que el ViewModel bajo test recargue.
    func simulateChange() {
        continuation?.yield(())
    }
}
