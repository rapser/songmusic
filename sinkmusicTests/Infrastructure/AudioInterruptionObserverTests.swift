//
//  AudioInterruptionObserverTests.swift
//  sinkmusicTests
//
//  Unidad extraída de `AudioPlayerService` (P2.13): pausa/reanuda ante interrupciones
//  de `AVAudioSession`. Se prueba llamando a `handle(...)` directo, sin postear
//  notificaciones reales.
//

import XCTest
import AVFoundation
@testable import sinkmusic

@MainActor
final class AudioInterruptionObserverTests: XCTestCase {

    private var sut: AudioInterruptionObserver!
    private var delegate: SpyDelegate!
    private var eventBus: MockEventBus!

    private let began = AVAudioSession.InterruptionType.began.rawValue
    private let ended = AVAudioSession.InterruptionType.ended.rawValue

    override func setUp() {
        super.setUp()
        eventBus = MockEventBus()
        delegate = SpyDelegate()
        sut = AudioInterruptionObserver(eventBus: eventBus, resumeDelay: .zero)
        sut.start(delegate: delegate)
    }

    override func tearDown() {
        sut = nil
        delegate = nil
        eventBus = nil
        super.tearDown()
    }

    func test_began_whilePlaying_pauses() async {
        delegate.isPlaying = true

        await sut.handle(rawType: began, shouldResume: false)

        XCTAssertEqual(delegate.pauseCallCount, 1)
    }

    func test_began_whileNotPlaying_doesNothing() async {
        delegate.isPlaying = false

        await sut.handle(rawType: began, shouldResume: false)

        XCTAssertEqual(delegate.pauseCallCount, 0)
    }

    func test_ended_afterInterruptedPause_resumes() async {
        delegate.isPlaying = true
        delegate.currentSongID = UUID()
        await sut.handle(rawType: began, shouldResume: false)

        await sut.handle(rawType: ended, shouldResume: true)

        XCTAssertEqual(delegate.resumeCallCount, 1)
    }

    func test_ended_withoutShouldResume_doesNotResume() async {
        delegate.isPlaying = true
        delegate.currentSongID = UUID()
        await sut.handle(rawType: began, shouldResume: false)

        await sut.handle(rawType: ended, shouldResume: false)

        XCTAssertEqual(delegate.resumeCallCount, 0)
    }

    func test_ended_withoutPriorInterruption_doesNotResume() async {
        await sut.handle(rawType: ended, shouldResume: true)
        XCTAssertEqual(delegate.resumeCallCount, 0)
    }

    func test_ended_resumeFails_emitsStateChangedFalse() async {
        let songID = UUID()
        delegate.isPlaying = true
        delegate.currentSongID = songID
        delegate.resumeReturns = false
        await sut.handle(rawType: began, shouldResume: false)

        await sut.handle(rawType: ended, shouldResume: true)

        let emitted = eventBus.emittedPlaybackEvents.contains { event in
            if case .stateChanged(let isPlaying, let id) = event { return isPlaying == false && id == songID }
            return false
        }
        XCTAssertTrue(emitted)
    }
}

@MainActor
private final class SpyDelegate: AudioInterruptionDelegate {
    var isPlaying = false
    var currentSongID: UUID?
    var pauseCallCount = 0
    var resumeCallCount = 0
    var resumeReturns = true

    func pauseForInterruption() {
        pauseCallCount += 1
        isPlaying = false
    }

    @discardableResult
    func resumeAfterInterruption() -> Bool {
        resumeCallCount += 1
        if resumeReturns { isPlaying = true }
        return resumeReturns
    }
}
