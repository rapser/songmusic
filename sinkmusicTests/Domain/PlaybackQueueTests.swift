//
//  PlaybackQueueTests.swift
//  sinkmusicTests
//
//  El algoritmo de la cola vivía dentro de `PlayerViewModel` y solo se podía ejercitar
//  levantando el ViewModel entero con sus mocks. Siendo un value type puro se prueba
//  directamente, y el aleatorio se inyecta para que los casos sean deterministas.
//

import XCTest
@testable import sinkmusic

final class PlaybackQueueTests: XCTestCase {

    private let a = UUID(), b = UUID(), c = UUID()

    private func makeQueue(
        _ songIDs: [UUID]? = nil,
        shuffle: Bool = false,
        repeatMode: RepeatMode = .off
    ) -> PlaybackQueue {
        PlaybackQueue(songIDs: songIDs ?? [a, b, c], isShuffleEnabled: shuffle, repeatMode: repeatMode)
    }

    /// Aleatorio determinista: siempre el primero de los candidatos.
    private let firstCandidate: ([UUID]) -> UUID? = { $0.first }

    // MARK: - Avance por acción del usuario

    func test_next_followsOrder() {
        let queue = makeQueue()
        XCTAssertEqual(queue.next(after: a), b)
        XCTAssertEqual(queue.next(after: b), c)
    }

    /// Pulsar "siguiente" en la última da la vuelta, haya o no repetición: el modo describe
    /// qué pasa al *terminar* una canción, no cuando el usuario pide otra.
    func test_next_wrapsAroundAtTheEnd_evenWithRepeatOff() {
        XCTAssertEqual(makeQueue(repeatMode: .off).next(after: c), a)
    }

    func test_previous_followsOrderBackwards() {
        let queue = makeQueue()
        XCTAssertEqual(queue.previous(before: c), b)
        XCTAssertEqual(queue.previous(before: b), a)
    }

    func test_previous_wrapsAroundAtTheStart() {
        XCTAssertEqual(makeQueue().previous(before: a), c)
    }

    func test_next_withShuffle_neverRepeatsTheCurrentSong() {
        let queue = makeQueue(shuffle: true)
        XCTAssertEqual(queue.next(after: a, pickRandom: firstCandidate), b)
        XCTAssertEqual(queue.next(after: b, pickRandom: firstCandidate), a)
    }

    /// Con una sola canción no hay "otra": en aleatorio se queda en ella en vez de no hacer nada.
    func test_next_withShuffle_singleSong_staysOnIt() {
        XCTAssertEqual(makeQueue([a], shuffle: true).next(after: a, pickRandom: firstCandidate), a)
    }

    func test_next_onEmptyQueue_isNil() {
        XCTAssertNil(makeQueue([]).next(after: a))
    }

    func test_next_whenSongIsNotInQueue_isNil() {
        XCTAssertNil(makeQueue([a, b]).next(after: c))
    }

    // MARK: - Avance porque la canción terminó

    func test_advance_withRepeatOff_continuesUntilTheLast() {
        let queue = makeQueue(repeatMode: .off)
        XCTAssertEqual(queue.advance(after: a), .play(songID: b))
        XCTAssertEqual(queue.advance(after: b), .play(songID: c))
    }

    /// La diferencia con `next`: aquí la última sí detiene la reproducción.
    func test_advance_withRepeatOff_stopsAtTheLast() {
        XCTAssertEqual(makeQueue(repeatMode: .off).advance(after: c), .stop)
    }

    func test_advance_withRepeatAll_wrapsAround() {
        XCTAssertEqual(makeQueue(repeatMode: .repeatAll).advance(after: c), .play(songID: a))
    }

    func test_advance_withRepeatOne_repeatsTheSameSong() {
        XCTAssertEqual(makeQueue(repeatMode: .repeatOne).advance(after: b), .play(songID: b))
    }

    /// En aleatorio no existe "la última", así que no se detiene aunque no haya repetición.
    func test_advance_withShuffleAndRepeatOff_doesNotStop() {
        let queue = makeQueue(shuffle: true, repeatMode: .off)
        XCTAssertEqual(queue.advance(after: c, pickRandom: firstCandidate), .play(songID: a))
    }

    func test_advance_onEmptyQueue_isIdle() {
        XCTAssertEqual(makeQueue([]).advance(after: a), .idle)
    }

    func test_advance_whenSongIsNotInQueue_isIdle() {
        XCTAssertEqual(makeQueue([a, b]).advance(after: c), .idle)
    }

    /// `repeatOne` no necesita que la canción esté en la cola: se repite a sí misma.
    func test_advance_withRepeatOne_worksEvenIfSongLeftTheQueue() {
        let queue = makeQueue([a, b], repeatMode: .repeatOne)
        XCTAssertEqual(queue.advance(after: c), .play(songID: c))
    }

    // MARK: - Contenido

    /// Cambiar de cola no debe reiniciar las preferencias del usuario.
    func test_replace_keepsShuffleAndRepeat() {
        var queue = makeQueue(shuffle: true, repeatMode: .repeatAll)
        queue.replace(with: [c])

        XCTAssertEqual(queue.songIDs, [c])
        XCTAssertTrue(queue.isShuffleEnabled)
        XCTAssertEqual(queue.repeatMode, .repeatAll)
    }

    func test_isEmpty() {
        XCTAssertTrue(makeQueue([]).isEmpty)
        XCTAssertFalse(makeQueue().isEmpty)
    }
}
