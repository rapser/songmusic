//
//  MockSearchReadStore.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockSearchReadStore: SearchReadStoreProtocol {

    var songs: [Song] = []
    var artistsValue: [String] = []
    var albumsValue: [String] = []

    private(set) var lastSearchQuery: String?
    private(set) var lastSearchArtist: String?
    private(set) var lastSearchAlbum: String?
    private(set) var lastSearchDownloadedOnly: Bool?

    private var continuation: AsyncStream<Void>.Continuation?
    private lazy var stream: AsyncStream<Void> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init() {
        _ = stream
    }

    func search(
        query: String?,
        artist: String?,
        album: String?,
        downloadedOnly: Bool,
        sortBy: SortOption
    ) async throws -> [Song] {
        lastSearchQuery = query
        lastSearchArtist = artist
        lastSearchAlbum = album
        lastSearchDownloadedOnly = downloadedOnly

        var results = songs
        if let query, !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(lowercaseQuery) || $0.artist.lowercased().contains(lowercaseQuery)
            }
        }
        if let artist, !artist.isEmpty {
            results = results.filter { $0.artist == artist }
        }
        if let album, !album.isEmpty {
            results = results.filter { $0.album == album }
        }
        if downloadedOnly {
            results = results.filter { $0.isDownloaded }
        }
        return results
    }

    func allArtists() async throws -> [String] { artistsValue }
    func allAlbums() async throws -> [String] { albumsValue }
    func mostPlayedSongs(limit: Int) async throws -> [Song] {
        Array(songs.filter { $0.playCount > 0 }.sorted { $0.playCount > $1.playCount }.prefix(limit))
    }
    func recentlyPlayedSongs(limit: Int) async throws -> [Song] {
        Array(songs.filter { $0.lastPlayedAt != nil }.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }.prefix(limit))
    }
    func downloadedSongs() async throws -> [Song] { songs.filter { $0.isDownloaded } }
    func notDownloadedSongs() async throws -> [Song] { songs.filter { !$0.isDownloaded } }

    func changes() -> AsyncStream<Void> { stream }

    /// Simula que algo relevante cambió, para que el ViewModel bajo test recargue.
    func simulateChange() {
        continuation?.yield(())
    }
}
