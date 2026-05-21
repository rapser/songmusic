//
//  MockMetadataRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockMetadataRepository: MetadataRepositoryProtocol {

    var metadata: SongMetadata?
    var extractCallCount = 0

    func extractMetadata(from url: URL) async -> SongMetadata? {
        extractCallCount += 1
        return metadata
    }
}
