//
//  MockPlaybackStateRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

final class MockPlaybackStateRepository: PlaybackStateRepositoryProtocol, @unchecked Sendable {

    var savedSongID: UUID?
    var savedTime: TimeInterval?
    var stateToLoad: (songID: UUID, time: TimeInterval)?

    var saveCallCount = 0
    var loadCallCount = 0
    var clearCallCount = 0

    func save(songID: UUID, time: TimeInterval) {
        saveCallCount += 1
        savedSongID = songID
        savedTime = time
    }

    func load() -> (songID: UUID, time: TimeInterval)? {
        loadCallCount += 1
        return stateToLoad
    }

    func clear() {
        clearCallCount += 1
        stateToLoad = nil
    }
}
