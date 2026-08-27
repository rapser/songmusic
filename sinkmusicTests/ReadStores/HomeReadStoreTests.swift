//
//  HomeReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class HomeReadStoreTests: XCTestCase {

    private func makeSUT(
        _ context: ModelContext,
        ranking: RankingWindowRepositoryProtocol? = nil
    ) -> HomeReadStore {
        HomeReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context, ranking: ranking),
            playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
            modelContext: context
        )
    }

    func test_recentlyPlayedSongs_ordersByLastPlayedDescending() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Old", isDownloaded: true, lastPlayedAt: Date(timeIntervalSinceNow: -300))
        try ReadStoreTestSupport.insertSong(context, title: "New", isDownloaded: true, lastPlayedAt: Date(timeIntervalSinceNow: -10))
        try ReadStoreTestSupport.insertSong(context, title: "Never", lastPlayedAt: nil)

        let sut = makeSUT(context)
        let songs = try await sut.recentlyPlayedSongs(limit: 10)

        XCTAssertEqual(songs.count, 2)
        XCTAssertEqual(songs.first?.title, "New")
    }

    func test_recentlyPlayedSongs_excludesRemovedDownloads() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "StillDownloaded", isDownloaded: true, lastPlayedAt: Date())
        try ReadStoreTestSupport.insertSong(context, title: "RemovedDownload", isDownloaded: false, lastPlayedAt: Date())

        let sut = makeSUT(context)
        let songs = try await sut.recentlyPlayedSongs(limit: 10)

        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs.first?.title, "StillDownloaded")
    }

    func test_mostPlayedSongs_excludesRemovedDownloads() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        let still = try ReadStoreTestSupport.insertSong(context, title: "StillDownloaded", isDownloaded: true)
        let removed = try ReadStoreTestSupport.insertSong(context, title: "RemovedDownload", isDownloaded: false)
        // Ambas con reproducciones recientes; solo la descargada debe salir en el ranking.
        for _ in 0..<5 { await ranking.registerPlay(songID: still.id) }
        for _ in 0..<9 { await ranking.registerPlay(songID: removed.id) }

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["StillDownloaded"])
    }

    func test_mostPlayedSongs_ordersByWindowedPlayCount() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        let a = try ReadStoreTestSupport.insertSong(context, title: "A", isDownloaded: true)
        let b = try ReadStoreTestSupport.insertSong(context, title: "B", isDownloaded: true)
        let c = try ReadStoreTestSupport.insertSong(context, title: "C", isDownloaded: true)
        for _ in 0..<2 { await ranking.registerPlay(songID: a.id) }
        for _ in 0..<5 { await ranking.registerPlay(songID: b.id) }
        // c nunca se reprodujo → no aparece en el ranking.
        _ = c

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["B", "A"])
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
