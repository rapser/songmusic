//
//  NowPlayingCenterTests.swift
//  sinkmusicTests
//
//  Cubre la unidad extraída de `AudioPlayerService` (P2.13): la lógica de Now Playing
//  en aislamiento, sin motor de audio.
//

import XCTest
import MediaPlayer
@testable import sinkmusic

@MainActor
final class NowPlayingCenterTests: XCTestCase {

    private var sut: NowPlayingCenter!

    override func setUp() {
        super.setUp()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        sut = NowPlayingCenter(eventBus: MockEventBus())
    }

    override func tearDown() {
        sut.clear()
        sut = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        super.tearDown()
    }

    private var info: [String: Any]? { MPNowPlayingInfoCenter.default().nowPlayingInfo }
    private func number(_ key: String) -> Double? { (info?[key] as? NSNumber)?.doubleValue }

    func test_setMetadata_writesFields() {
        sut.setMetadata(title: "T", artist: "A", album: "Alb", duration: 200, artwork: nil,
                        elapsed: 30, isPlaying: true, realDuration: 0)

        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "T")
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "A")
        XCTAssertEqual(info?[MPMediaItemPropertyAlbumTitle] as? String, "Alb")
        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 200)
        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 30)
        XCTAssertEqual(number(MPNowPlayingInfoPropertyPlaybackRate), 1)
    }

    func test_setMetadata_emptyAlbumOmitsKey() {
        sut.setMetadata(title: "T", artist: "A", album: "", duration: 1, artwork: nil,
                        elapsed: 0, isPlaying: false, realDuration: 0)
        XCTAssertNil(info?[MPMediaItemPropertyAlbumTitle])
    }

    func test_push_realDurationOverridesMetadataDuration() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 200, artwork: nil,
                        elapsed: 0, isPlaying: false, realDuration: 0)

        sut.push(elapsed: 5, isPlaying: true, realDuration: 333)

        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 333)
    }

    func test_updateTime_setsElapsedAndKeepsMetadata() {
        sut.setMetadata(title: "Song", artist: "A", album: nil, duration: 200, artwork: nil,
                        elapsed: 0, isPlaying: true, realDuration: 0)

        sut.updateTime(elapsed: 90, duration: nil, isPlaying: true, realDuration: 0)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 90)
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Song")
    }

    func test_clear_removesInfo() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 1, artwork: nil,
                        elapsed: 0, isPlaying: true, realDuration: 0)
        XCTAssertNotNil(info)

        sut.clear()

        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func test_pushIfStale_skipsWhenRecentlyPushed() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 1, artwork: nil,
                        elapsed: 0, isPlaying: true, realDuration: 0)

        // `setMetadata` ya empujó ahora mismo; un `pushIfStale` inmediato (< 1s) NO re-empuja.
        sut.pushIfStale(elapsed: 42, isPlaying: true, realDuration: 0, minInterval: 1.0)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 0)
    }
}
