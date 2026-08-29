//
//  PlaylistOrderPersistenceTests.swift
//  sinkmusicTests
//
//  P2.20 — el orden de una playlist vive en `PlaylistItemDTO` (no en el CSV `songOrder`).
//  Estos tests ejercen `PlaylistLocalDataSource` sobre un store SwiftData real en memoria.
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class PlaylistOrderPersistenceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var sut: PlaylistLocalDataSource!
    private var songSource: SongLocalDataSource!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ReadStoreTestSupport.makeInMemoryContainer()
        sut = PlaylistLocalDataSource(modelContext: context)
        songSource = SongLocalDataSource(modelContext: context)
    }

    override func tearDown() {
        container = nil
        sut = nil
        songSource = nil
        super.tearDown()
    }

    private func makeSongs(_ count: Int) throws -> [SongDTO] {
        let songs = (0..<count).map { index in
            SongDTO(title: "S\(index)", artist: "A", fileID: "f-\(UUID().uuidString)", isDownloaded: true)
        }
        songs.forEach { context.insert($0) }
        try context.save()
        return songs
    }

    private func emptyPlaylist() throws -> PlaylistDTO {
        let playlist = PlaylistDTO(name: "P")
        context.insert(playlist)
        try context.save()
        return playlist
    }

    private func orderIDs(_ playlist: PlaylistDTO) throws -> [UUID] {
        try sut.orderedSongs(for: playlist).map(\.id)
    }

    func test_addSong_appendsAtEnd_andPersistsItems() throws {
        let songs = try makeSongs(3)
        let playlist = try emptyPlaylist()

        for song in songs {
            try sut.addSong(songID: song.id, toPlaylist: playlist.id, songDataSource: songSource)
        }

        XCTAssertEqual(try orderIDs(playlist), songs.map(\.id))

        let items = try context.fetch(FetchDescriptor<PlaylistItemDTO>())
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(Set(items.map(\.position)), [0, 1, 2])
    }

    func test_removeSong_keepsOrder_andRenormalizesPositions() throws {
        let songs = try makeSongs(4)
        let playlist = try emptyPlaylist()
        for song in songs {
            try sut.addSong(songID: song.id, toPlaylist: playlist.id, songDataSource: songSource)
        }

        try sut.removeSong(songID: songs[1].id, fromPlaylist: playlist.id)

        XCTAssertEqual(try orderIDs(playlist), [songs[0].id, songs[2].id, songs[3].id])
        let positions = try context.fetch(FetchDescriptor<PlaylistItemDTO>()).map(\.position).sorted()
        XCTAssertEqual(positions, [0, 1, 2])
    }

    func test_updateSongsOrder_replacesSequence() throws {
        let songs = try makeSongs(3)
        let playlist = try emptyPlaylist()
        for song in songs {
            try sut.addSong(songID: song.id, toPlaylist: playlist.id, songDataSource: songSource)
        }

        let reversed = songs.map(\.id).reversed().map { $0 }
        try sut.updateSongsOrder(playlistID: playlist.id, songIDs: reversed, songDataSource: songSource)

        XCTAssertEqual(try orderIDs(playlist), reversed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlaylistItemDTO>()).count, 3)
    }

    func test_removeSongFromAllPlaylists_dropsItemEverywhere() throws {
        let songs = try makeSongs(3)
        let p1 = try emptyPlaylist()
        let p2 = try emptyPlaylist()
        for song in songs {
            try sut.addSong(songID: song.id, toPlaylist: p1.id, songDataSource: songSource)
        }
        try sut.addSong(songID: songs[0].id, toPlaylist: p2.id, songDataSource: songSource)

        try sut.removeSongFromAllPlaylists(songID: songs[0].id)

        XCTAssertEqual(try orderIDs(p1), [songs[1].id, songs[2].id])
        XCTAssertEqual(try orderIDs(p2), [])
        let remaining = try context.fetch(FetchDescriptor<PlaylistItemDTO>())
        XCTAssertFalse(remaining.contains { $0.songID == songs[0].id })
    }

    func test_backfill_isIdempotent() throws {
        let songs = try makeSongs(2)
        let playlist = try emptyPlaylist()
        playlist.songs = songs
        playlist.songOrder = [songs[1], songs[0]].map(\.id.uuidString).joined(separator: ",")
        try context.save()

        _ = try orderIDs(playlist)
        _ = try orderIDs(playlist)

        let items = try context.fetch(FetchDescriptor<PlaylistItemDTO>())
        XCTAssertEqual(items.count, 2, "El backfill no debe duplicar items en lecturas sucesivas")
        XCTAssertEqual(try orderIDs(playlist), [songs[1].id, songs[0].id])
    }
}
