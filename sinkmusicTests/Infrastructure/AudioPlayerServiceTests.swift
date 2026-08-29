//
//  AudioPlayerServiceTests.swift
//  sinkmusicTests
//
//  Red de seguridad ANTES de partir `AudioPlayerService` (P2.13).
//  Cubre la lógica de Now Playing (Lock Screen / Control Center), que es observable
//  vía `MPNowPlayingInfoCenter.default()` sin necesidad de reproducir audio real.
//  La lógica del motor de audio (AVAudioEngine, scheduleID, songFinished) necesita
//  un archivo real + engine arrancado y se cubre en pruebas manuales / de dispositivo.
//

import XCTest
import MediaPlayer
@testable import sinkmusic

@MainActor
final class AudioPlayerServiceTests: XCTestCase {

    private var sut: AudioPlayerService!

    override func setUp() {
        super.setUp()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        sut = AudioPlayerService(eventBus: MockEventBus())
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        super.tearDown()
    }

    private var nowPlaying: [String: Any]? {
        MPNowPlayingInfoCenter.default().nowPlayingInfo
    }

    private func number(_ key: String) -> Double? {
        (nowPlaying?[key] as? NSNumber)?.doubleValue
    }

    // MARK: - Estado inicial

    func test_isPlaying_falseInitially() {
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - setNowPlayingMetadata

    func test_setNowPlayingMetadata_writesTitleArtistAlbumDuration() {
        sut.setNowPlayingMetadata(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 355, artwork: nil)

        XCTAssertEqual(nowPlaying?[MPMediaItemPropertyTitle] as? String, "Bohemian Rhapsody")
        XCTAssertEqual(nowPlaying?[MPMediaItemPropertyArtist] as? String, "Queen")
        XCTAssertEqual(nowPlaying?[MPMediaItemPropertyAlbumTitle] as? String, "A Night at the Opera")
        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 355)
    }

    func test_setNowPlayingMetadata_emptyAlbum_omitsAlbumKey() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: "", duration: 100, artwork: nil)
        XCTAssertNil(nowPlaying?[MPMediaItemPropertyAlbumTitle])
    }

    func test_setNowPlayingMetadata_nonFiniteDuration_coercedToZero() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: .infinity, artwork: nil)
        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 0)
    }

    func test_setNowPlayingMetadata_setsPausedStateWhenNotPlaying() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: 100, artwork: nil)
        XCTAssertEqual(number(MPNowPlayingInfoPropertyPlaybackRate), 0)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().playbackState, .paused)
    }

    // MARK: - updateNowPlayingTime

    func test_updateNowPlayingTime_updatesElapsed() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: 200, artwork: nil)

        sut.updateNowPlayingTime(120, duration: nil)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 120)
    }

    func test_updateNowPlayingTime_updatesDurationWhenProvided() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: 200, artwork: nil)

        sut.updateNowPlayingTime(10, duration: 321)

        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 321)
    }

    func test_updateNowPlayingTime_ignoresNonPositiveDuration() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: 200, artwork: nil)

        sut.updateNowPlayingTime(10, duration: 0)

        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 200)
    }

    // MARK: - stop

    func test_stop_clearsNowPlayingInfo() {
        sut.setNowPlayingMetadata(title: "T", artist: "A", album: nil, duration: 100, artwork: nil)
        XCTAssertNotNil(nowPlaying)

        sut.stop()

        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().playbackState, .stopped)
    }

    // MARK: - pause idempotente

    func test_pause_whenIdle_doesNotCrashAndStaysPaused() {
        sut.pause()
        XCTAssertFalse(sut.isPlaying)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().playbackState, .paused)
    }
}
