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
                        progress: PlaybackProgress(elapsed: 30, duration: 0), isPlaying: true)

        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "T")
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "A")
        XCTAssertEqual(info?[MPMediaItemPropertyAlbumTitle] as? String, "Alb")
        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 200)
        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 30)
        XCTAssertEqual(number(MPNowPlayingInfoPropertyPlaybackRate), 1)
    }

    func test_setMetadata_emptyAlbumOmitsKey() {
        sut.setMetadata(title: "T", artist: "A", album: "", duration: 1, artwork: nil,
                        progress: .zero, isPlaying: false)
        XCTAssertNil(info?[MPMediaItemPropertyAlbumTitle])
    }

    func test_push_realDurationOverridesMetadataDuration() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 200, artwork: nil,
                        progress: .zero, isPlaying: false)

        sut.push(PlaybackProgress(elapsed: 5, duration: 333), isPlaying: true)

        XCTAssertEqual(number(MPMediaItemPropertyPlaybackDuration), 333)
    }

    func test_push_keepsMetadataAndUpdatesElapsed() {
        sut.setMetadata(title: "Song", artist: "A", album: nil, duration: 200, artwork: nil,
                        progress: .zero, isPlaying: true)

        sut.push(PlaybackProgress(elapsed: 90, duration: 0), isPlaying: true)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 90)
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Song")
    }

    /// La posición que llega aquí ya viene acotada por construcción: el widget nativo no
    /// puede recibir un tiempo mayor que la duración ni aunque quien lo llame se equivoque.
    func test_push_elapsedIsClampedToDuration() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 217, artwork: nil,
                        progress: .zero, isPlaying: true)

        sut.push(PlaybackProgress(elapsed: 256, duration: 217), isPlaying: true)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 217)
    }

    func test_clear_removesInfo() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 1, artwork: nil,
                        progress: .zero, isPlaying: true)
        XCTAssertNotNil(info)

        sut.clear()

        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func test_pushIfStale_skipsWhenRecentlyPushed() {
        sut.setMetadata(title: "T", artist: "A", album: nil, duration: 1, artwork: nil,
                        progress: .zero, isPlaying: true)

        // `setMetadata` ya empujó ahora mismo; un `pushIfStale` inmediato (< 1s) NO re-empuja.
        sut.pushIfStale(PlaybackProgress(elapsed: 42, duration: 0), isPlaying: true, minInterval: 1.0)

        XCTAssertEqual(number(MPNowPlayingInfoPropertyElapsedPlaybackTime), 0)
    }
}
