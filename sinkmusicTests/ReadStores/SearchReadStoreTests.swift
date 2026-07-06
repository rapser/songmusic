//
//  SearchReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class SearchReadStoreTests: XCTestCase {

    private func makeSUT(_ context: ModelContext) -> SearchReadStore {
        SearchReadStore(
            searchUseCases: ReadStoreTestSupport.makeSearchUseCases(context),
            modelContext: context
        )
    }

    func test_search_matchesTitle() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Bohemian Rhapsody")
        try ReadStoreTestSupport.insertSong(context, title: "Hotel California")

        let sut = makeSUT(context)
        let results = try await sut.search(query: "bohemian", artist: nil, album: nil, downloadedOnly: false, sortBy: .title)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Bohemian Rhapsody")
    }

    func test_search_matchesAlbum() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Track 1", album: "Abbey Road")
        try ReadStoreTestSupport.insertSong(context, title: "Track 2", album: "Dark Side")

        let sut = makeSUT(context)
        let results = try await sut.search(query: "abbey", artist: nil, album: nil, downloadedOnly: false, sortBy: .title)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.album, "Abbey Road")
    }

    func test_search_emptyQuery_returnsAll() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "A")
        try ReadStoreTestSupport.insertSong(context, title: "B")

        let sut = makeSUT(context)
        let results = try await sut.search(query: nil, artist: nil, album: nil, downloadedOnly: false, sortBy: .title)

        XCTAssertEqual(results.count, 2)
    }

    func test_changes_emitsSignal_forChangeMadeThroughDataSourceDirectly() async throws {
        // Simula "cambio hecho en otra pantalla": se escribe vía SongLocalDataSource
        // directamente, sin pasar por SearchReadStore, y este debe enterarse igual.
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

        try ReadStoreTestSupport.insertSong(context, title: "Nueva canción")
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        XCTAssertEqual(received, 1)
    }
}
