//
//  RankingWindowRepositoryImplTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

final class RankingWindowRepositoryImplTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.ranking.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSUT(now: @escaping () -> Date) -> RankingWindowRepositoryImpl {
        RankingWindowRepositoryImpl(defaults: defaults, now: now)
    }

    func test_registerPlay_accumulatesWithinWindow() {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let song = UUID()

        sut.registerPlay(songID: song)
        clock = clock.addingTimeInterval(3600) // +1h
        sut.registerPlay(songID: song)
        clock = clock.addingTimeInterval(3600)
        sut.registerPlay(songID: song)

        XCTAssertEqual(sut.activeCounts()[song], 3)
    }

    func test_activeCounts_dropsSongWhoseWindowExpired() {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let fresh = UUID()
        let stale = UUID()

        sut.registerPlay(songID: stale)
        clock = clock.addingTimeInterval(2 * 24 * 3600) // stale abrió su ventana 2 días antes que fresh
        sut.registerPlay(songID: fresh)

        // Avanzar hasta que la ventana de `stale` (7 días) haya caducado pero la de `fresh` no.
        clock = clock.addingTimeInterval(6 * 24 * 3600)

        let counts = sut.activeCounts()
        XCTAssertNil(counts[stale])
        XCTAssertEqual(counts[fresh], 1)
    }

    func test_registerPlay_afterExpiry_startsFreshWindow() {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let song = UUID()

        for _ in 0..<10 { sut.registerPlay(songID: song) }
        clock = clock.addingTimeInterval(RankingWindowRepositoryImpl.windowDuration + 60) // caduca
        XCTAssertNil(sut.activeCounts()[song])

        sut.registerPlay(songID: song) // nueva ventana
        XCTAssertEqual(sut.activeCounts()[song], 1)
    }

    func test_remove_and_clear() {
        let sut = makeSUT(now: { Date() })
        let a = UUID(); let b = UUID()
        sut.registerPlay(songID: a)
        sut.registerPlay(songID: b)

        sut.remove(songID: a)
        XCTAssertNil(sut.activeCounts()[a])
        XCTAssertEqual(sut.activeCounts()[b], 1)

        sut.clear()
        XCTAssertTrue(sut.activeCounts().isEmpty)
    }
}
