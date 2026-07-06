//
//  SearchReadStoreProtocol.swift
//  sinkmusic
//

import Foundation

/// Read-side reactivo para búsqueda.
/// SOLID: Interface Segregation — expone solo lo que SearchViewModel consume.
@MainActor
protocol SearchReadStoreProtocol: AnyObject {
    func search(
        query: String?,
        artist: String?,
        album: String?,
        downloadedOnly: Bool,
        sortBy: SortOption
    ) async throws -> [Song]

    func allArtists() async throws -> [String]
    func allAlbums() async throws -> [String]
    func mostPlayedSongs(limit: Int) async throws -> [Song]
    func recentlyPlayedSongs(limit: Int) async throws -> [Song]
    func downloadedSongs() async throws -> [Song]
    func notDownloadedSongs() async throws -> [Song]

    /// Emite cada vez que cambia una canción, aunque haya sido modificada desde otra pantalla.
    func changes() -> AsyncStream<Void>
}
