//
//  EqualizerUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class EqualizerUseCasesTests: XCTestCase {

    private var sut: EqualizerUseCases!
    private var mockAudioPlayer: MockAudioPlayerRepository!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        sut = EqualizerUseCases(audioPlayerRepository: mockAudioPlayer)
    }

    override func tearDown() {
        sut = nil
        mockAudioPlayer = nil
        super.tearDown()
    }

    // MARK: - updateBands()

    func test_updateBands_forwardsToAudioPlayer() async {
        let bands: [Float] = [3, 6, -2, 0, 4, 5]

        await sut.updateBands(bands)

        XCTAssertEqual(mockAudioPlayer.updateEqualizerCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastEqualizerBands, bands)
    }

    // MARK: - applyPreset()

    func test_applyPreset_sendsPresetBands() async {
        await sut.applyPreset(.rock)

        XCTAssertEqual(mockAudioPlayer.updateEqualizerCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastEqualizerBands, EqualizerPreset.rock.bands)
    }

    func test_applyPreset_flat_sendsAllZeros() async {
        await sut.applyPreset(.flat)

        XCTAssertEqual(mockAudioPlayer.lastEqualizerBands, [0, 0, 0, 0, 0, 0])
    }

    // MARK: - reset()

    func test_reset_sendsAllZeroBands() async {
        await sut.reset()

        XCTAssertEqual(mockAudioPlayer.updateEqualizerCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastEqualizerBands, [0, 0, 0, 0, 0, 0])
    }

    func test_reset_callsAudioPlayerOnce() async {
        await sut.reset()
        await sut.reset()

        XCTAssertEqual(mockAudioPlayer.updateEqualizerCallCount, 2)
    }

    // MARK: - EqualizerPreset bands

    func test_flatPreset_hasExactlySixZeroBands() {
        let bands = EqualizerPreset.flat.bands
        XCTAssertEqual(bands.count, 6)
        XCTAssertTrue(bands.allSatisfy { $0 == 0 })
    }

    func test_rockPreset_hasSixBands() {
        XCTAssertEqual(EqualizerPreset.rock.bands.count, 6)
    }

    func test_bassBoosterPreset_hasPositiveLowBands() {
        let bands = EqualizerPreset.bassBooster.bands
        XCTAssertGreaterThan(bands[0], 0)
        XCTAssertGreaterThan(bands[1], 0)
    }

    func test_bassReducerPreset_hasNegativeLowBands() {
        let bands = EqualizerPreset.bassReducer.bands
        XCTAssertLessThan(bands[0], 0)
        XCTAssertLessThan(bands[1], 0)
    }

    func test_allPresetsHaveSixBands() {
        for preset in EqualizerPreset.allCases {
            XCTAssertEqual(preset.bands.count, 6, "Preset \(preset.rawValue) should have 6 bands")
        }
    }
}
