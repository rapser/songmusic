//
//  RankingWindowRepositoryImplTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class RankingWindowRepositoryImplTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: RankingWindowEntryDTO.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeSUT(now: @escaping () -> Date) -> RankingWindowRepositoryImpl {
        RankingWindowRepositoryImpl(
            dataSource: RankingWindowLocalDataSource(modelContext: container.mainContext),
            now: now
        )
    }

    func test_registerPlay_accumulatesWithinWindow() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let song = UUID()

        await sut.registerPlay(songID: song)
        clock = clock.addingTimeInterval(3600)
        await sut.registerPlay(songID: song)
        clock = clock.addingTimeInterval(3600)
        await sut.registerPlay(songID: song)

        let counts = await sut.activeCounts()
        XCTAssertEqual(counts[song], 3)
    }

    func test_activeCounts_ignoresSongWhoseWindowExpired() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let fresh = UUID()
        let stale = UUID()

        await sut.registerPlay(songID: stale)
        clock = clock.addingTimeInterval(2 * 24 * 3600) // stale abrió su ventana 2 días antes
        await sut.registerPlay(songID: fresh)

        clock = clock.addingTimeInterval(6 * 24 * 3600) // stale caduca (8 días), fresh no (6)

        let counts = await sut.activeCounts()
        XCTAssertNil(counts[stale])
        XCTAssertEqual(counts[fresh], 1)
    }

    func test_registerPlay_afterExpiry_startsFreshWindow() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let song = UUID()

        for _ in 0..<10 { await sut.registerPlay(songID: song) }
        clock = clock.addingTimeInterval(RankingWindowRepositoryImpl.windowDuration + 60)

        var counts = await sut.activeCounts()
        XCTAssertNil(counts[song])

        await sut.registerPlay(songID: song) // nueva ventana
        counts = await sut.activeCounts()
        XCTAssertEqual(counts[song], 1)
    }

    func test_registerPlay_purgesExpiredRows() async throws {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let sut = makeSUT(now: { clock })
        let stale = UUID()

        await sut.registerPlay(songID: stale)
        clock = clock.addingTimeInterval(RankingWindowRepositoryImpl.windowDuration + 60)
        await sut.registerPlay(songID: UUID()) // dispara la limpieza oportunista

        let ds = RankingWindowLocalDataSource(modelContext: container.mainContext)
        XCTAssertNil(try ds.entry(for: stale))
    }

    func test_remove_and_clear() async {
        let sut = makeSUT(now: { Date() })
        let a = UUID(); let b = UUID()
        await sut.registerPlay(songID: a)
        await sut.registerPlay(songID: b)

        await sut.remove(songID: a)
        var counts = await sut.activeCounts()
        XCTAssertNil(counts[a])
        XCTAssertEqual(counts[b], 1)

        await sut.clear()
        counts = await sut.activeCounts()
        XCTAssertTrue(counts.isEmpty)
    }
}
