//
//  HomeReadStoreProtocol.swift
//  sinkmusic
//

import Foundation

/// Read-side reactivo para la pantalla Home.
/// SOLID: Interface Segregation — expone solo lo que HomeViewModel consume.
@MainActor
protocol HomeReadStoreProtocol: AnyObject {
    func playlists() async throws -> [Playlist]
    func mostPlayedPlaylists(limit: Int) async throws -> [Playlist]
    func recentlyPlayedSongs(limit: Int) async throws -> [Song]
    func mostPlayedSongs(limit: Int) async throws -> [Song]
    func downloadedSongs() async throws -> [Song]

    /// Emite cada vez que cambia algo relevante para Home (canciones o playlists).
    func changes() -> AsyncStream<Void>
}
