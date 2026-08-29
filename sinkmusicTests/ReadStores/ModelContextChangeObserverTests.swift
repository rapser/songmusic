//
//  ModelContextChangeObserverTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class ModelContextChangeObserverTests: XCTestCase {

    private func collectSignals(from stream: AsyncStream<Void>, count: Int, timeoutMS: UInt64 = 500) async -> Int {
        var received = 0
        let task = Task {
            for await _ in stream {
                received += 1
                if received >= count { break }
            }
        }
        try? await Task.sleep(nanoseconds: timeoutMS * 1_000_000)
        task.cancel()
        return received
    }

    func test_insertSong_emitsSignal_whenObservingSongDTO() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 1) }
        try await Task.sleep(nanoseconds: 50_000_000)

        try ReadStoreTestSupport.insertSong(context)

        let received = await task.value
        XCTAssertEqual(received, 1)
    }

    func test_updateSong_emitsSignal() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, title: "Old")
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 1) }
        try await Task.sleep(nanoseconds: 50_000_000)

        song.title = "New"
        try context.save()

        let received = await task.value
        XCTAssertEqual(received, 1)
    }

    func test_deleteSong_emitsSignal() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context)
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 1) }
        try await Task.sleep(nanoseconds: 50_000_000)

        context.delete(song)
        try context.save()

        let received = await task.value
        XCTAssertEqual(received, 1)
    }

    func test_insertPlaylist_doesNotEmitSignal_whenObservingOnlySongDTO() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 1, timeoutMS: 200) }
        try await Task.sleep(nanoseconds: 50_000_000)

        try ReadStoreTestSupport.insertPlaylist(context)

        let received = await task.value
        XCTAssertEqual(received, 0)
    }

    // MARK: - suspend() / resume()  (usado por "Descargar todo" vía ReactiveReloadGate)

    func test_suspend_buffersChanges_thenEmitsOnceOnResume() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 5, timeoutMS: 400) }
        try await Task.sleep(nanoseconds: 50_000_000)

        observer.suspend()
        for _ in 0..<4 {
            try ReadStoreTestSupport.insertSong(context)
        }
        try await Task.sleep(nanoseconds: 200_000_000) // ninguna señal mientras está suspendido

        observer.resume()

        let received = await task.value
        XCTAssertEqual(received, 1, "los cambios suspendidos deben colapsar en una sola señal")
    }

    func test_resume_withNoChanges_doesNotEmit() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 1, timeoutMS: 200) }
        try await Task.sleep(nanoseconds: 50_000_000)

        observer.suspend()
        observer.resume()

        let received = await task.value
        XCTAssertEqual(received, 0)
    }
}
