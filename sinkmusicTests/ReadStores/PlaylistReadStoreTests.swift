//
//  PlaylistReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class PlaylistReadStoreTests: XCTestCase {

    private func makeSUT(_ context: ModelContext) -> PlaylistReadStore {
        PlaylistReadStore(
            playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
            modelContext: context
        )
    }

    func test_songsInPlaylist_returnsAssociatedSongs() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song1 = try ReadStoreTestSupport.insertSong(context, title: "A")
        let song2 = try ReadStoreTestSupport.insertSong(context, title: "B")
        let playlist = try ReadStoreTestSupport.insertPlaylist(context, songs: [song1, song2])

        let sut = makeSUT(context)
        let songs = try await sut.songs(inPlaylist: playlist.id)

        XCTAssertEqual(songs.count, 2)
    }

    func test_stats_reflectsPlaylistSongs() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true, playCount: 4)
        let playlist = try ReadStoreTestSupport.insertPlaylist(context, songs: [song])

        let sut = makeSUT(context)
        let stats = try await sut.stats(forPlaylist: playlist.id)

        XCTAssertEqual(stats.songCount, 1)
        XCTAssertEqual(stats.totalPlays, 4)
        XCTAssertEqual(stats.downloadedSongs, 1)
    }

    func test_changes_emitsSignal_whenSongAddedToPlaylist() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        // Playlist y canción se crean ANTES de suscribirse, para que la señal que
        // esperamos venga únicamente de la operación addSong, no de estas inserciones.
        let playlist = try ReadStoreTestSupport.insertPlaylist(context)
        let song = try ReadStoreTestSupport.insertSong(context)
        let sut = makeSUT(context)

        var received = 0
        let task = Task {
            for await _ in sut.changes() {
                received += 1
                break
            }
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        let playlistDataSource = PlaylistLocalDataSource(modelContext: context)
        try playlistDataSource.addSong(
            songID: song.id,
            toPlaylist: playlist.id,
            songDataSource: ReadStoreTestSupport.makeSongLocalDataSource(context)
        )
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        XCTAssertEqual(received, 1)
    }
}
