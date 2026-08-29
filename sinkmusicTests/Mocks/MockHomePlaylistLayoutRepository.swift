//
//  MockHomePlaylistLayoutRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

final class MockHomePlaylistLayoutRepository: HomePlaylistLayoutRepositoryProtocol, @unchecked Sendable {

    var stateToLoad: (order: [UUID], homeCount: Int)?

    var savedOrder: [UUID]?
    var savedHomeCount: Int?
    var saveCallCount = 0

    func load() -> (order: [UUID], homeCount: Int)? {
        stateToLoad
    }

    func save(order: [UUID], homeCount: Int) {
        saveCallCount += 1
        savedOrder = order
        savedHomeCount = homeCount
    }
}
