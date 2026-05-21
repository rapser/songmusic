//
//  MockAudioPlayerRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockAudioPlayerRepository: AudioPlayerRepositoryProtocol {

    var playCallCount = 0
    var pauseCallCount = 0
    var stopCallCount = 0
    var seekCallCount = 0
    var updateEqualizerCallCount = 0
    var updateNowPlayingCallCount = 0

    var lastPlayedSongID: UUID?
    var lastPlayedURL: URL?
    var lastSeekTime: TimeInterval?
    var lastEqualizerBands: [Float]?

    var isPlayingValue = false
    var shouldThrowOnPlay = false

    func play(songID: UUID, url: URL) async throws {
        if shouldThrowOnPlay { throw SongError.fileNotFound }
        playCallCount += 1
        lastPlayedSongID = songID
        lastPlayedURL = url
        isPlayingValue = true
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

    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        artwork: Data?
    ) async {
        updateNowPlayingCallCount += 1
    }
}
