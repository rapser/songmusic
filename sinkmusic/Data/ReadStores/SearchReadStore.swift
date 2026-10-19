//
//  SearchReadStore.swift
//  sinkmusic
//

import Foundation
import SwiftData

/// Implementación reactiva de `SearchReadStoreProtocol`.
/// Delega los reads a `SearchUseCases` y añade la señal de `changes()`
/// observando `ModelContext.didSave` filtrado a `SongDTO`.
@MainActor
final class SearchReadStore: SearchReadStoreProtocol {

    private let searchUseCases: SearchUseCases
    private let aggregationUseCases: LibraryAggregationUseCases
    private let observer: ModelContextChangeObserver

    init(
        searchUseCases: SearchUseCases,
        aggregationUseCases: LibraryAggregationUseCases,
        modelContext: ModelContext
    ) {
        self.searchUseCases = searchUseCases
        self.aggregationUseCases = aggregationUseCases
        self.observer = ModelContextChangeObserver(
            modelContext: modelContext,
            relevantEntityNames: ["SongDTO"]
        )
    }

    func search(
        query: String?,
        artist: String?,
        album: String?,
        downloadedOnly: Bool,
        sortBy: SortOption
    ) async throws -> [Song] {
        try await searchUseCases.advancedSearch(
            query: query,
            artist: artist,
            album: album,
            downloadedOnly: downloadedOnly,
            sortBy: sortBy
        )
    }

    func allArtists() async throws -> [String] {
        try await aggregationUseCases.getAllArtists()
    }

    func allAlbums() async throws -> [String] {
        try await aggregationUseCases.getAllAlbums()
    }

    func mostPlayedSongs(limit: Int) async throws -> [Song] {
        try await searchUseCases.getMostPlayedSongs(limit: limit)
    }

    func recentlyPlayedSongs(limit: Int) async throws -> [Song] {
        try await searchUseCases.getRecentlyPlayedSongs(limit: limit)
    }

    func downloadedSongs() async throws -> [Song] {
        try await searchUseCases.getDownloadedSongs()
    }

    func notDownloadedSongs() async throws -> [Song] {
        try await searchUseCases.getNotDownloadedSongs()
    }

    func changes() -> AsyncStream<Void> {
        observer.stream()
    }

    func setReactiveReloads(suspended: Bool) {
        suspended ? observer.suspend() : observer.resume()
    }
}
