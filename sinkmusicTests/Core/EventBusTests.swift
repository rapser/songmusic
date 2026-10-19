//
//  EventBusTests.swift
//  sinkmusicTests
//
//  Fija la propiedad que el bus tenía rota: un evento emitido justo después de suscribirse
//  debe llegar. El registro de la continuation estaba diferido a un `Task { @MainActor }`,
//  así que entre que `playbackEvents()` devolvía el stream y esa tarea corría había una
//  ventana en la que `emit` no veía al suscriptor y el evento se perdía sin rastro.
//

import XCTest
@testable import sinkmusic

@MainActor
final class EventBusTests: XCTestCase {

    private var sut: EventBus!

    override func setUp() {
        super.setUp()
        sut = EventBus()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Registro síncrono de la suscripción

    func test_playbackEvents_deliversEventEmittedRightAfterSubscribing() async {
        let songID = UUID()
        let delivered = expectation(description: "El evento emitido justo tras suscribirse llega")

        let stream = sut.playbackEvents()
        sut.emit(.songFinished(songID))

        let consumer = Task {
            for await event in stream {
                if case .songFinished(let id) = event, id == songID {
                    delivered.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [delivered], timeout: 1.0)
        consumer.cancel()
    }

    func test_downloadEvents_deliversEventEmittedRightAfterSubscribing() async {
        let songID = UUID()
        let delivered = expectation(description: "El evento emitido justo tras suscribirse llega")

        let stream = sut.downloadEvents()
        sut.emit(DownloadEvent.started(songID: songID))

        let consumer = Task {
            for await event in stream {
                if case .started(let id) = event, id == songID {
                    delivered.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [delivered], timeout: 1.0)
        consumer.cancel()
    }

    // MARK: - Fan-out

    func test_playbackEvents_deliversToEverySubscriber() async {
        let songID = UUID()
        let first = expectation(description: "Primer suscriptor")
        let second = expectation(description: "Segundo suscriptor")

        let streamA = sut.playbackEvents()
        let streamB = sut.playbackEvents()
        sut.emit(.songFinished(songID))

        let consumerA = Task { for await _ in streamA { first.fulfill(); return } }
        let consumerB = Task { for await _ in streamB { second.fulfill(); return } }

        await fulfillment(of: [first, second], timeout: 1.0)
        consumerA.cancel()
        consumerB.cancel()
    }

    /// El buffer es `.unbounded`: un consumidor que llega tarde no pierde lo ya emitido.
    func test_playbackEvents_buffersEventsUntilConsumed() async {
        let delivered = expectation(description: "Llegan los tres eventos emitidos antes de consumir")
        delivered.expectedFulfillmentCount = 3

        let stream = sut.playbackEvents()
        for _ in 0..<3 {
            sut.emit(.songFinished(UUID()))
        }

        let consumer = Task {
            for await _ in stream { delivered.fulfill() }
        }

        await fulfillment(of: [delivered], timeout: 1.0)
        consumer.cancel()
    }
}
