//
//  EqualizerViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class EqualizerViewModelTests: XCTestCase {

    private var sut: EqualizerViewModel!
    private var mockAudioPlayer: MockAudioPlayerRepository!
    private var equalizerUseCases: EqualizerUseCases!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        equalizerUseCases = EqualizerUseCases(audioPlayerRepository: mockAudioPlayer)
        sut = EqualizerViewModel(equalizerUseCases: equalizerUseCases)
    }

    override func tearDown() {
        sut = nil
        equalizerUseCases = nil
        mockAudioPlayer = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_allBandsAreZero() {
        XCTAssertEqual(sut.band60Hz, 0.0)
        XCTAssertEqual(sut.band150Hz, 0.0)
        XCTAssertEqual(sut.band400Hz, 0.0)
        XCTAssertEqual(sut.band1kHz, 0.0)
        XCTAssertEqual(sut.band2_4kHz, 0.0)
        XCTAssertEqual(sut.band15kHz, 0.0)
        XCTAssertEqual(sut.selectedPreset, .flat)
    }

    // MARK: - applyPreset()

    func test_applyPreset_setsSelectedPreset() async {
        await sut.applyPreset(.rock)

        XCTAssertEqual(sut.selectedPreset, .rock)
        XCTAssertFalse(sut.isCustom)
    }

    func test_applyPreset_updatesBandValues() async {
        await sut.applyPreset(.bassBooster)

        let expected = EqualizerPreset.bassBooster.bands
        XCTAssertEqual(sut.band60Hz, expected[0])
        XCTAssertEqual(sut.band150Hz, expected[1])
        XCTAssertEqual(sut.band400Hz, expected[2])
    }

    func test_applyPreset_callsAudioPlayerRepository() async {
        await sut.applyPreset(.pop)

        XCTAssertEqual(mockAudioPlayer.updateEqualizerCallCount, 1)
    }

    // MARK: - reset()

    func test_reset_setsAllBandsToZero() async {
        await sut.applyPreset(.rock)

        await sut.reset()

        XCTAssertEqual(sut.band60Hz, 0.0)
        XCTAssertEqual(sut.band150Hz, 0.0)
        XCTAssertEqual(sut.band400Hz, 0.0)
        XCTAssertEqual(sut.selectedPreset, .flat)
        XCTAssertFalse(sut.isCustom)
    }

    // MARK: - updateBand()

    func test_updateBand_atIndex_updatesCorrectBand() async {
        await sut.updateBand(at: 0, value: 5.0)

        XCTAssertEqual(sut.band60Hz, 5.0)
        XCTAssertTrue(sut.isCustom)
    }

    func test_updateBand_invalidIndex_doesNotCrash() async {
        await sut.updateBand(at: 99, value: 5.0)
        // No assertion needed — just verify no crash
    }

    // MARK: - currentBands

    func test_currentBands_reflectsBandProperties() async {
        await sut.applyPreset(.jazz)

        let bands = sut.currentBands
        XCTAssertEqual(bands.count, 6)
        XCTAssertEqual(bands[0], sut.band60Hz)
        XCTAssertEqual(bands[5], sut.band15kHz)
    }

    // MARK: - availablePresets

    func test_availablePresets_containsExpectedCount() {
        XCTAssertFalse(sut.availablePresets.isEmpty)
        XCTAssertTrue(sut.availablePresets.contains(.flat))
    }
}
