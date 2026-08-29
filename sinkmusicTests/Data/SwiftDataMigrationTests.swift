//
//  SwiftDataMigrationTests.swift
//  sinkmusicTests
//
//  P0.1 — Verifica que introducir `AppMigrationPlan` sobre un store ya existente
//  (creado ANTES, con la migración implícita) NO pierde datos: ni canciones, ni
//  playlists, ni el `songOrder` (CSV de UUIDs que es la fuente de verdad del orden).
//
//  El store se crea en un fichero temporal en disco (no `isStoredInMemoryOnly`)
//  porque la migración solo ocurre al abrir un store persistido con un esquema
//  distinto al que lo escribió.
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class SwiftDataMigrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("store.sqlite")
    }

    override func tearDownWithError() throws {
        if let dir = storeURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: dir)
        }
        storeURL = nil
        try super.tearDownWithError()
    }

    func test_openingLegacyStoreWithMigrationPlan_preservesSongsPlaylistsAndOrder() throws {
        let songIDs = (0..<3).map { _ in UUID() }
        let expectedOrder = songIDs.map(\.uuidString).joined(separator: ",")
        let playlistID = UUID()

        // 1. Store "heredado": creado SIN migrationPlan, tal como estaba antes de P0.1.
        do {
            let legacyConfig = ModelConfiguration(url: storeURL)
            let legacy = try ModelContainer(
                for: SongDTO.self, PlaylistDTO.self, RankingWindowEntryDTO.self,
                configurations: legacyConfig
            )
            let ctx = legacy.mainContext

            let songs = songIDs.enumerated().map { index, id in
                SongDTO(id: id, title: "Song \(index)", artist: "Artist \(index)",
                        fileID: "file-\(index)", isDownloaded: true)
            }
            songs.forEach { ctx.insert($0) }
            try ctx.save()

            let playlist = PlaylistDTO(id: playlistID, name: "Mi Playlist")
            ctx.insert(playlist)
            try ctx.save()
            playlist.songs = songs
            playlist.songOrder = expectedOrder
            try ctx.save()
        }

        // 2. Reabrir el MISMO store con el migrationPlan explícito.
        let migratedConfig = ModelConfiguration(url: storeURL)
        let migrated = try ModelContainer(
            for: AppSchemaV1.schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: migratedConfig
        )
        let ctx = migrated.mainContext

        let migratedSongs = try ctx.fetch(FetchDescriptor<SongDTO>())
        XCTAssertEqual(migratedSongs.count, 3, "Se perdieron canciones al migrar")
        XCTAssertEqual(Set(migratedSongs.map(\.id)), Set(songIDs))
        XCTAssertTrue(migratedSongs.allSatisfy(\.isDownloaded))

        let migratedPlaylists = try ctx.fetch(FetchDescriptor<PlaylistDTO>())
        XCTAssertEqual(migratedPlaylists.count, 1, "Se perdieron playlists al migrar")

        let playlist = try XCTUnwrap(migratedPlaylists.first)
        XCTAssertEqual(playlist.id, playlistID)
        XCTAssertEqual(playlist.name, "Mi Playlist")
        XCTAssertEqual(playlist.songOrder, expectedOrder, "El orden (songOrder) no sobrevivió a la migración")
        XCTAssertEqual(playlist.songs.count, 3, "La relación playlist↔canciones no sobrevivió a la migración")
    }

    func test_freshStoreWithMigrationPlan_opensEmpty() throws {
        let config = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(
            for: AppSchemaV1.schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: config
        )
        let ctx = container.mainContext

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SongDTO>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PlaylistDTO>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<RankingWindowEntryDTO>()).count, 0)
    }
}
