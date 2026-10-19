//
//  PlaybackClockTests.swift
//  sinkmusicTests
//
//  El reloj es una máquina de estados pura: no toca AVFoundation ni temporizadores, así que
//  los dos fallos del motor que vigila (pasarse del final y atascarse) se reproducen aquí
//  exactamente, sin audio real ni esperas.
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlaybackClockTests: XCTestCase {

    private var sut: PlaybackClock!

    /// Duración de ejemplo: 3:37, la canción de la incidencia original.
    private let duration: TimeInterval = 217

    override func setUp() {
        super.setUp()
        sut = PlaybackClock()
        sut.load(duration: duration, startingAt: 0, at: 0)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Posición acotada

    func test_tick_advancesWithEngine() {
        let result = sut.tick(rawPosition: 12.5, at: 1)

        XCTAssertEqual(result, .progress(PlaybackProgress(elapsed: 12.5, duration: duration)))
        XCTAssertEqual(sut.elapsed, 12.5)
    }

    func test_position_neverExceedsDuration() {
        _ = sut.tick(rawPosition: duration - 0.1, at: 1)

        // Dentro del margen de fin: todavía no es fin de pista, pero la posición ya no puede
        // pasar de la duración.
        let result = sut.tick(rawPosition: duration + 0.1, at: 1.1)

        XCTAssertEqual(sut.elapsed, duration)
        XCTAssertEqual(result, .progress(PlaybackProgress(elapsed: duration, duration: duration)))
    }

    // MARK: - Fin de pista sin aviso del motor

    /// El fallo original: el nodo se queda sin buffers, sigue "reproduciendo" silencio y su
    /// posición se dispara (04:16 en una canción de 03:37) sin que llegue ningún aviso.
    func test_tick_rawPositionBeyondDuration_reportsReachedEnd() {
        let result = sut.tick(rawPosition: 256, at: 10)

        XCTAssertEqual(result, .reachedEnd(PlaybackProgress(elapsed: duration, duration: duration)))
    }

    func test_tick_withinEndTolerance_doesNotReportEndYet() {
        let result = sut.tick(rawPosition: duration + PlaybackClock.endOfTrackTolerance / 2, at: 10)

        XCTAssertEqual(result, .progress(PlaybackProgress(elapsed: duration, duration: duration)))
    }

    /// Al final de la pista la posición se acota y deja de avanzar. Ese caso debe resolverse
    /// como fin de pista, nunca como atasco: el margen de fin es menor que el de atasco.
    func test_endOfTrackWins_overStallDetection() {
        var now: CFTimeInterval = 0
        _ = sut.tick(rawPosition: duration - 0.05, at: now)

        var sawStall = false
        var sawEnd = false

        // El motor sigue renderizando silencio en tiempo real a partir del final.
        while now < 5 {
            now += 0.1
            let raw = duration - 0.05 + now
            switch sut.tick(rawPosition: raw, at: now) {
            case .stalled: sawStall = true
            case .reachedEnd: sawEnd = true
            case .progress: break
            }
            if sawEnd { break }
        }

        XCTAssertTrue(sawEnd)
        XCTAssertFalse(sawStall, "Un final de pista no debe confundirse con un motor atascado")
    }

    func test_markReachedEnd_leavesPositionAtTheEnd() {
        _ = sut.tick(rawPosition: 100, at: 1)

        sut.markReachedEnd()

        XCTAssertTrue(sut.hasReachedEnd)
        XCTAssertEqual(sut.elapsed, duration)
    }

    // MARK: - Motor atascado

    /// El fallo inverso: el motor se para y deja de entregar frames, sin emitir ninguna
    /// notificación de ruta ni de configuración a la que reaccionar.
    func test_tick_noAdvanceForStallTimeout_reportsStalled() {
        _ = sut.tick(rawPosition: 30, at: 0)

        XCTAssertEqual(sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout - 0.1),
                       .progress(PlaybackProgress(elapsed: 30, duration: duration)))
        XCTAssertEqual(sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout),
                       .stalled(PlaybackProgress(elapsed: 30, duration: duration)))
    }

    func test_tick_stallIsReportedOnlyOnce() {
        _ = sut.tick(rawPosition: 30, at: 0)
        _ = sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout)

        let next = sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout + 1)

        XCTAssertEqual(next, .progress(PlaybackProgress(elapsed: 30, duration: duration)))
    }

    /// Que el nodo no reporte posición mientras se le dio orden de reproducir es un atasco
    /// igual que una posición congelada.
    func test_tick_nilPosition_reportsStalledAfterTimeout() {
        _ = sut.tick(rawPosition: 30, at: 0)

        XCTAssertEqual(sut.tick(rawPosition: nil, at: PlaybackClock.stallTimeout),
                       .stalled(PlaybackProgress(elapsed: 30, duration: duration)))
    }

    func test_tick_advanceClearsStall() {
        _ = sut.tick(rawPosition: 30, at: 0)
        _ = sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout)

        // El motor vuelve a entregar audio...
        _ = sut.tick(rawPosition: 31, at: PlaybackClock.stallTimeout + 0.1)
        // ...y a partir de ahí se puede volver a informar de un atasco nuevo.
        let next = sut.tick(rawPosition: 31, at: PlaybackClock.stallTimeout * 2 + 0.2)

        XCTAssertEqual(next, .stalled(PlaybackProgress(elapsed: 31, duration: duration)))
    }

    // MARK: - Transiciones

    func test_seek_clearsEndAndStall() {
        _ = sut.tick(rawPosition: 30, at: 0)
        _ = sut.tick(rawPosition: 30, at: PlaybackClock.stallTimeout)
        sut.markReachedEnd()

        sut.seek(to: 60, at: 10)

        XCTAssertFalse(sut.hasReachedEnd)
        XCTAssertEqual(sut.elapsed, 60)
        // La vigilancia de atasco arranca de cero desde el salto.
        XCTAssertEqual(sut.tick(rawPosition: 60, at: 10.1),
                       .progress(PlaybackProgress(elapsed: 60, duration: duration)))
    }

    func test_resumed_doesNotCountThePauseAsStall() {
        _ = sut.tick(rawPosition: 30, at: 0)

        // Diez segundos en pausa, sin ticks.
        sut.resumed(at: 10)

        XCTAssertEqual(sut.tick(rawPosition: 30, at: 10.1),
                       .progress(PlaybackProgress(elapsed: 30, duration: duration)))
    }

    func test_align_updatesPositionWithoutClearingEnd() {
        sut.markReachedEnd()

        sut.align(to: 50)

        XCTAssertEqual(sut.elapsed, 50)
        XCTAssertTrue(sut.hasReachedEnd)
    }

    func test_reset_clearsEverything() {
        _ = sut.tick(rawPosition: 100, at: 1)
        sut.markReachedEnd()

        sut.reset()

        XCTAssertEqual(sut.duration, 0)
        XCTAssertEqual(sut.elapsed, 0)
        XCTAssertFalse(sut.hasReachedEnd)
        XCTAssertEqual(sut.progress, .zero)
    }

    func test_load_withRestoredPosition() {
        sut.load(duration: 300, startingAt: 145, at: 0)

        XCTAssertEqual(sut.progress, PlaybackProgress(elapsed: 145, duration: 300))
        XCTAssertFalse(sut.hasReachedEnd)
    }

    // MARK: - Duración desconocida

    func test_unknownDuration_doesNotReportEnd() {
        sut.load(duration: 0, startingAt: 0, at: 0)

        let result = sut.tick(rawPosition: 9999, at: 1)

        XCTAssertEqual(result, .progress(PlaybackProgress(elapsed: 9999, duration: 0)))
    }
}
