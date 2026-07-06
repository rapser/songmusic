//
//  HomeReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class HomeReadStoreTests: XCTestCase {

    private func makeSUT(_ context: ModelContext) -> HomeReadStore {
        HomeReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
            playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
            modelContext: context
        )
    }

    func test_recentlyPlayedSongs_ordersByLastPlayedDescending() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Old", lastPlayedAt: Date(timeIntervalSinceNow: -300))
        try ReadStoreTestSupport.insertSong(context, title: "New", lastPlayedAt: Date(timeIntervalSinceNow: -10))
        try ReadStoreTestSupport.insertSong(context, title: "Never", lastPlayedAt: nil)

        let sut = makeSUT(context)
        let songs = try await sut.recentlyPlayedSongs(limit: 10)

        XCTAssertEqual(songs.count, 2)
        XCTAssertEqual(songs.first?.title, "New")
    }

    func test_downloadedSongs_returnsOnlyDownloaded() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        try ReadStoreTestSupport.insertSong(context, isDownloaded: false)

        let sut = makeSUT(context)
        let songs = try await sut.downloadedSongs()

        XCTAssertEqual(songs.count, 1)
    }

    func test_playlists_returnsInsertedPlaylists() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertPlaylist(context, name: "Rock")
        try ReadStoreTestSupport.insertPlaylist(context, name: "Jazz")

        let sut = makeSUT(context)
        let playlists = try await sut.playlists()

        XCTAssertEqual(playlists.count, 2)
    }

    func test_changes_emitsSignal_whenPlaylistInserted() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let sut = makeSUT(context)

        var received = 0
        let task = Task {
            for await _ in sut.changes() {
                received += 1
                break
            }
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        try ReadStoreTestSupport.insertPlaylist(context)
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        XCTAssertEqual(received, 1)
    }
}
