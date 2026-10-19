//
//  SongPlayStatsLocalDataSourceTests.swift
//  sinkmusicTests
//
//  La parte delicada de sacar `playCount` de `SongDTO` no es escribir en la entidad nueva:
//  es no perder lo que ya había. Estos tests cubren el backfill perezoso desde los campos
//  viejos, que es la migración de datos (no hay `MigrationStage`: la entidad es aditiva).
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class SongPlayStatsLocalDataSourceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var sut: SongPlayStatsLocalDataSource!

    override func setUp() async throws {
        try await super.setUp()
        container = try ReadStoreTestSupport.makeInMemoryContainer()
        sut = SongPlayStatsLocalDataSource(modelContext: context)
    }

    override func tearDown() async throws {
        sut = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Escritura

    func test_increment_fromScratch_startsAtOne() throws {
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)

        try sut.increment(songID: song.id)

        XCTAssertEqual(try sut.stats(for: song.id)?.playCount, 1)
        XCTAssertNotNil(try sut.stats(for: song.id)?.lastPlayedAt)
    }

    func test_increment_twice_counts() throws {
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)

        try sut.increment(songID: song.id)
        try sut.increment(songID: song.id)

        XCTAssertEqual(try sut.stats(for: song.id)?.playCount, 2)
    }

    /// La escritura caliente **no** debe tocar la fila de la canción: es justo el motivo de
    /// que la entidad exista.
    func test_increment_doesNotTouchTheSongRow() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 7)

        try sut.increment(songID: song.id)

        XCTAssertEqual(song.playCount, 7, "El campo viejo queda congelado como semilla")
        XCTAssertEqual(try sut.stats(for: song.id)?.playCount, 8, "El contador real sube")
    }

    func test_increment_updatesLastPlayedAt() throws {
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        let when = Date(timeIntervalSince1970: 1_000_000)

        try sut.increment(songID: song.id, at: when)

        XCTAssertEqual(try sut.stats(for: song.id)?.lastPlayedAt, when)
    }

    // MARK: - Backfill desde los campos viejos

    /// Lo que arrastra una instalación anterior: contador en `SongDTO`, sin fila propia.
    func test_firstRead_migratesLegacyCounters() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 12)

        let stats = try sut.allStats()

        XCTAssertEqual(stats[song.id]?.playCount, 12)
    }

    func test_firstRead_migratesLastPlayedAtToo() throws {
        let when = Date(timeIntervalSince1970: 500_000)
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 3, lastPlayedAt: when)

        let stats = try sut.allStats()

        XCTAssertEqual(stats[song.id]?.lastPlayedAt, when)
    }

    /// Una canción nunca escuchada no necesita fila: se lee como cero.
    func test_songsNeverPlayed_getNoRow() throws {
        try ReadStoreTestSupport.insertLegacySong(context, playCount: 0)

        XCTAssertTrue(try sut.allStats().isEmpty)
    }

    /// El riesgo real de un backfill: contar dos veces. Leer varias veces no puede sumar.
    func test_backfill_isIdempotent() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 5)

        _ = try sut.allStats()
        _ = try sut.allStats()
        let stats = try sut.allStats()

        XCTAssertEqual(stats[song.id]?.playCount, 5)
    }

    /// Y tampoco puede sumar con otra instancia del DataSource (cada una lleva su propio
    /// control de "ya migré").
    func test_backfill_isIdempotentAcrossInstances() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 5)

        _ = try sut.allStats()
        let other = SongPlayStatsLocalDataSource(modelContext: context)
        let stats = try other.allStats()

        XCTAssertEqual(stats[song.id]?.playCount, 5)
    }

    /// El caso que perdería datos de verdad: reproducir una canción legacy **antes** de
    /// haber leído nada. Si el incremento no sembrara desde el campo viejo, el histórico
    /// se reiniciaría a 1.
    func test_increment_beforeAnyRead_seedsFromLegacyInsteadOfResetting() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 40)

        try sut.increment(songID: song.id)

        XCTAssertEqual(try sut.stats(for: song.id)?.playCount, 41)
    }

    /// Y después del incremento, el backfill no debe volver a sembrar encima.
    func test_backfill_afterAnIncrement_doesNotOverwrite() throws {
        let song = try ReadStoreTestSupport.insertLegacySong(context, playCount: 40)
        try sut.increment(songID: song.id)

        let other = SongPlayStatsLocalDataSource(modelContext: context)

        XCTAssertEqual(try other.allStats()[song.id]?.playCount, 41)
    }

    // MARK: - Recientes

    func test_recentlyPlayedIDs_areOrderedNewestFirst() throws {
        let older = try ReadStoreTestSupport.insertSong(context, title: "Older", isDownloaded: true)
        let newer = try ReadStoreTestSupport.insertSong(context, title: "Newer", isDownloaded: true)

        try sut.increment(songID: older.id, at: Date(timeIntervalSince1970: 100))
        try sut.increment(songID: newer.id, at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(try sut.recentlyPlayedIDs(), [newer.id, older.id])
    }

    func test_recentlyPlayedIDs_excludesSongsNeverPlayed() throws {
        try ReadStoreTestSupport.insertSong(context, isDownloaded: true)

        XCTAssertTrue(try sut.recentlyPlayedIDs().isEmpty)
    }

    // MARK: - Borrado

    /// Borrar la canción no debe dejar su contador huérfano.
    func test_delete_removesTheRow() throws {
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        try sut.increment(songID: song.id)

        try sut.delete(songID: song.id)

        XCTAssertNil(try sut.stats(for: song.id))
    }

    func test_deleteAll_removesEveryRow() throws {
        let a = try ReadStoreTestSupport.insertSong(context, title: "A", isDownloaded: true)
        let b = try ReadStoreTestSupport.insertSong(context, title: "B", isDownloaded: true)
        try sut.increment(songID: a.id)
        try sut.increment(songID: b.id)

        try sut.deleteAll()

        XCTAssertTrue(try sut.allStats().isEmpty)
    }
}
