//
//  MockAudioPlayerRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockAudioPlayerRepository: AudioPlayerRepositoryProtocol {

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
    var shouldThrowOnPlay = false

    /// Simula si el motor tiene una pista cargada que se pueda reanudar.
    /// `false` = arranque en frío, el UseCase debe caer a un `play` real.
    var canResumeValue = false

    func play(songID: UUID, url: URL, startTime: TimeInterval) async throws {
        if shouldThrowOnPlay { throw SongError.fileNotFound }
        playCallCount += 1
        lastPlayedSongID = songID
        lastPlayedURL = url
        lastStartTime = startTime
        isPlayingValue = true
        canResumeValue = true
    }

    func resume() async -> Bool {
        resumeCallCount += 1
        guard canResumeValue else { return false }
        isPlayingValue = true
        return true
    }

    func pause() async {
        pauseCallCount += 1
        isPlayingValue = false
    }

    func stop() async {
        stopCallCount += 1
        isPlayingValue = false
    }

    func seek(to time: TimeInterval) async {
        seekCallCount += 1
        lastSeekTime = time
    }

    func isPlaying() async -> Bool { isPlayingValue }

    func updateEqualizer(bands: [Float]) async {
        updateEqualizerCallCount += 1
        lastEqualizerBands = bands
    }

    func setNowPlayingMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?
    ) async {
        setNowPlayingMetadataCallCount += 1
    }

    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?) async {
        updateNowPlayingTimeCallCount += 1
    }
}
