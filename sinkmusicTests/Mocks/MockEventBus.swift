//
//  MockEventBus.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockEventBus: EventBusProtocol {

    // MARK: - Observable State

    var authUserID: String?
    var isAuthenticated: Bool = false
    var playbackState: PlaybackState = .idle
    var playbackTimeInfo: PlaybackTimeInfo = .zero

    // MARK: - Emit tracking

    private(set) var emittedPlaybackEvents: [PlaybackEvent] = []
    private(set) var emittedDownloadEvents: [DownloadEvent] = []
    private(set) var emittedAuthEvents: [AuthEvent] = []

    // MARK: - Streams (controlables desde tests)

    private var playbackContinuation: AsyncStream<PlaybackEvent>.Continuation?
    private var downloadContinuation: AsyncStream<DownloadEvent>.Continuation?
    private var authContinuation: AsyncStream<AuthEvent>.Continuation?

    private lazy var playbackStream: AsyncStream<PlaybackEvent> = {
        AsyncStream { [weak self] continuation in
            self?.playbackContinuation = continuation
        }
    }()

    private lazy var downloadStream: AsyncStream<DownloadEvent> = {
        AsyncStream { [weak self] continuation in
            self?.downloadContinuation = continuation
        }
    }()

    private lazy var authStream: AsyncStream<AuthEvent> = {
        AsyncStream { [weak self] continuation in
            self?.authContinuation = continuation
        }
    }()

    // MARK: - Init (pre-inicializa streams para que las continuations estén disponibles)

    init() {
        _ = playbackStream
        _ = downloadStream
        _ = authStream
    }

    // MARK: - Emit

    func emit(_ event: PlaybackEvent) {
        emittedPlaybackEvents.append(event)
        playbackContinuation?.yield(event)
    }

    func emit(_ event: DownloadEvent) {
        emittedDownloadEvents.append(event)
        downloadContinuation?.yield(event)
    }

    func emit(_ event: AuthEvent) {
        emittedAuthEvents.append(event)
        authContinuation?.yield(event)
    }

    // MARK: - Streams

    func playbackEvents() -> AsyncStream<PlaybackEvent> { playbackStream }
    func downloadEvents() -> AsyncStream<DownloadEvent> { downloadStream }
    func authEvents() -> AsyncStream<AuthEvent> { authStream }
}
