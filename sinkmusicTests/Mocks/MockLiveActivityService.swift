//
//  MockLiveActivityService.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockLiveActivityService: LiveActivityServiceProtocol {

    // MARK: - State

    var hasActiveActivity: Bool = false

    // MARK: - Call tracking

    var startCallCount = 0
    var updateCallCount = 0
    var endCallCount = 0

    var lastStartedSongID: UUID?
    var lastStartedTitle: String?
    var lastIsPlaying: Bool?

    // MARK: - Protocol

    func startActivity(
        songID: UUID,
        songTitle: String,
        artistName: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        artworkThumbnail: Data?
    ) {
        startCallCount += 1
        lastStartedSongID = songID
        lastStartedTitle = songTitle
        lastIsPlaying = isPlaying
        hasActiveActivity = true
    }

    func updateActivity(
        songTitle: String,
        artistName: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        artworkThumbnail: Data?
    ) {
        updateCallCount += 1
        lastIsPlaying = isPlaying
    }

    func endActivity() {
        endCallCount += 1
        hasActiveActivity = false
    }
}
