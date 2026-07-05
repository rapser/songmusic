//
//  DownloadFailureClassifierTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

final class DownloadFailureClassifierTests: XCTestCase {

    func test_classifier_mapsURLErrorToNetworkUnavailable() {
        let failure = DownloadFailure(error: URLError(.notConnectedToInternet))

        XCTAssertEqual(failure.kind, .networkUnavailable)
        XCTAssertTrue(failure.kind.shouldSuggestRetry)
    }

    func test_classifier_mapsDownloadErrorSongNotFoundToFileNotFound() {
        let failure = DownloadFailure(error: DownloadError.songNotFound)

        XCTAssertEqual(failure.kind, .fileNotFound)
        XCTAssertFalse(failure.kind.shouldSuggestRetry)
    }

    func test_classifier_mapsMegaRateLimitToQuotaExceeded() {
        let failure = DownloadFailure(error: MegaError.rateLimitExceeded(retryAfter: 3600))

        XCTAssertEqual(failure.kind, .quotaExceeded)
        XCTAssertFalse(failure.kind.shouldSuggestRetry)
    }
}
