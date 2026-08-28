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

        // Suscribirse ANTES de disparar el cambio: `changes()` registra la continuación de
        // forma síncrona y el `AsyncStream` bufferiza, así que la señal no se pierde aunque
        // el `Task` aún no haya empezado a iterar. Evita la carrera de los `Task.sleep`.
        let stream = sut.changes()
        let emitted = expectation(description: "changes() emite tras insertar una canción")
        let task = Task {
            for await _ in stream {
                emitted.fulfill()
                break
            }
        }

        try ReadStoreTestSupport.insertSong(context)

        await fulfillment(of: [emitted], timeout: 2.0)
        task.cancel()
    }
}
