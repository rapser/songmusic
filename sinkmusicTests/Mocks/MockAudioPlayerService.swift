//
//  MockAudioPlayerService.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockAudioPlayerService: AudioPlayerServiceProtocol {

    var playCallCount = 0
    var resumeCallCount = 0
    var pauseCallCount = 0
    var stopCallCount = 0
    var seekCallCount = 0
    var updateEqualizerCallCount = 0
    var setNowPlayingMetadataCallCount = 0
    var updateNowPlayingTimeCallCount = 0

    var lastPlayedSongID: UUID?
    var lastPlayedURL: URL?
    var lastStartTime: TimeInterval?
    var lastSeekTime: TimeInterval?
    var lastEqualizerBands: [Float]?

    var isPlayingValue = false

    /// Simula si el motor tiene una pista cargada que se pueda reanudar.
    /// `false` = arranque en frío, el UseCase debe caer a un `play` real.
    var canResumeValue = false

    var isPlaying: Bool { isPlayingValue }

    func play(songID: UUID, url: URL, startTime: TimeInterval) {
        playCallCount += 1
        lastPlayedSongID = songID
        lastPlayedURL = url
        lastStartTime = startTime
        isPlayingValue = true
        canResumeValue = true
    }

    func resume() -> Bool {
        resumeCallCount += 1
        guard canResumeValue else { return false }
        isPlayingValue = true
        return true
    }

    func pause() {
        pauseCallCount += 1
        isPlayingValue = false
    }

    func stop() {
        stopCallCount += 1
        isPlayingValue = false
    }

    func seek(to time: TimeInterval) {
        seekCallCount += 1
        lastSeekTime = time
    }

    func updateEqualizer(bands: [Float]) {
        updateEqualizerCallCount += 1
        lastEqualizerBands = bands
    }

    func setNowPlayingMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?
    ) {
        setNowPlayingMetadataCallCount += 1
    }

    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?) {
        updateNowPlayingTimeCallCount += 1
    }
}
