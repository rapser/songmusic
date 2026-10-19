//
//  AudioEqualizerTests.swift
//  sinkmusicTests
//
//  Configurar el ecualizador no necesita motor ni sesión de audio: `AVAudioUnitEQ` acepta
//  parámetros estando suelto. Mientras esto vivía dentro de `AudioPlayerService` no había
//  forma de comprobarlo sin levantar el grafo entero.
//

import XCTest
@testable import sinkmusic

@MainActor
final class AudioEqualizerTests: XCTestCase {

    private var sut: AudioEqualizer!

    override func setUp() {
        super.setUp()
        sut = AudioEqualizer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Estado inicial

    /// Por defecto no debe tocar la señal: plano y en bypass.
    func test_startsFlatAndBypassed() {
        XCTAssertEqual(sut.gains, Array(repeating: 0, count: AudioEqualizer.frequencies.count))
        XCTAssertTrue(sut.bypassedBands.allSatisfy { $0 })
    }

    // MARK: - apply

    func test_apply_setsEachGain() {
        sut.apply(gains: [1, -2, 3, -4, 5, -6])

        XCTAssertEqual(sut.gains, [1, -2, 3, -4, 5, -6])
    }

    /// Una banda a 0 dB no hace nada, así que vuelve a bypass.
    func test_apply_bypassesOnlyTheBandsAtZero() {
        sut.apply(gains: [6, 0, -6, 0, 0, 3])

        XCTAssertEqual(sut.bypassedBands, [false, true, false, true, true, false])
    }

    /// La UI no debe poder romper el grafo pasando un array de otro tamaño.
    func test_apply_withTooManyGains_ignoresTheExtras() {
        sut.apply(gains: [1, 2, 3, 4, 5, 6, 7, 8, 9])

        XCTAssertEqual(sut.gains, [1, 2, 3, 4, 5, 6])
    }

    func test_apply_withFewerGains_leavesTheRestUntouched() {
        sut.apply(gains: [6, 6, 6, 6, 6, 6])
        sut.apply(gains: [1, 2])

        XCTAssertEqual(sut.gains, [1, 2, 6, 6, 6, 6])
    }

    // MARK: - reset

    func test_reset_returnsToFlatAndBypassed() {
        sut.apply(gains: [6, -6, 3, -3, 1, -1])
        sut.reset()

        XCTAssertEqual(sut.gains, Array(repeating: 0, count: AudioEqualizer.frequencies.count))
        XCTAssertTrue(sut.bypassedBands.allSatisfy { $0 })
    }

    // MARK: - Bandas

    /// El número de bandas lo define la tabla de frecuencias, no un literal repartido.
    func test_bandCount_matchesTheFrequencyTable() {
        XCTAssertEqual(AudioEqualizer.frequencies, [60, 150, 400, 1000, 2400, 15000])
        XCTAssertEqual(sut.gains.count, AudioEqualizer.frequencies.count)
    }
}
