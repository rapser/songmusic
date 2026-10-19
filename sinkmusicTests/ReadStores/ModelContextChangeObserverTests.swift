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

    // MARK: - Flanco de subida

    /// De esto depende que los ViewModels puedan NO recargar a mano tras cada mutación.
    /// Con el debounce solo de cola, una escritura suelta tardaba 120 ms en llegar a la UI.
    func test_singleWrite_emitsImmediately_notAfterTheDebounceWindow() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])

        // El stream se toma antes de provocar el cambio, y se espera con `fulfillment`:
        // aquí lo que se mide es *cuándo* llega la señal, así que no vale un `sleep` fijo.
        let stream = observer.stream()
        let signalled = expectation(description: "señal de cambio")
        let task = Task { @MainActor in
            for await _ in stream {
                signalled.fulfill()
                break
            }
        }
        try await Task.sleep(for: .milliseconds(50)) // que el consumidor esté escuchando

        let writtenAt = ContinuousClock.now
        try ReadStoreTestSupport.insertSong(context)
        await fulfillment(of: [signalled], timeout: 1.0)
        let delay = ContinuousClock.now - writtenAt
        task.cancel()

        XCTAssertLessThan(delay, .milliseconds(60),
                          "La primera señal no debe esperar la ventana de 120 ms del debounce")
    }

    /// Y el coalescing sigue existiendo: una ráfaga no produce una señal por escritura.
    /// Produce dos —el arranque inmediato y el cierre de la ventana—, no diez.
    func test_burst_emitsTwice_theLeadingEdgeAndTheTrailingOne() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 10, timeoutMS: 500) }
        try await Task.sleep(nanoseconds: 50_000_000)

        for _ in 0..<10 {
            try ReadStoreTestSupport.insertSong(context)
        }

        let received = await task.value
        XCTAssertEqual(received, 2, "10 escrituras seguidas: una inmediata y una al cerrar la ventana")
    }

    /// Dos escrituras separadas por más que la ventana son dos acciones distintas del
    /// usuario, y las dos deben verse al instante.
    func test_writesFurtherApartThanTheWindow_bothEmitImmediately() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let observer = ModelContextChangeObserver(modelContext: context, relevantEntityNames: ["SongDTO"])
        let stream = observer.stream()

        let task = Task { await collectSignals(from: stream, count: 2, timeoutMS: 400) }
        try await Task.sleep(nanoseconds: 50_000_000)

        try ReadStoreTestSupport.insertSong(context)
        try await Task.sleep(nanoseconds: 200_000_000) // > 120 ms: se cierra la ventana
        try ReadStoreTestSupport.insertSong(context)

        let received = await task.value
        XCTAssertEqual(received, 2)
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
