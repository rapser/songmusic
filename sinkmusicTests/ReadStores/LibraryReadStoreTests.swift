//
//  LibraryReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class LibraryReadStoreTests: XCTestCase {

    func test_allSongs_returnsInsertedSongs() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "A")
        try ReadStoreTestSupport.insertSong(context, title: "B")

        let sut = LibraryReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
            modelContext: context
        )

        let songs = try await sut.allSongs()
        XCTAssertEqual(songs.count, 2)
    }

    func test_stats_reflectsInsertedSongs() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, isDownloaded: true, playCount: 3)
        try ReadStoreTestSupport.insertSong(context, isDownloaded: false, playCount: 2)

        let sut = LibraryReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
            modelContext: context
        )

        let stats = try await sut.stats()
        XCTAssertEqual(stats.totalSongs, 2)
        XCTAssertEqual(stats.downloadedSongs, 1)
        XCTAssertEqual(stats.totalPlays, 5)
    }

    func test_changes_emitsSignal_afterInsert() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let sut = LibraryReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
            modelContext: context
        )

        var received = 0
        let task = Task {
            for await _ in sut.changes() {
                received += 1
                break
            }
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        try ReadStoreTestSupport.insertSong(context)
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        XCTAssertEqual(received, 1)
    }
}
