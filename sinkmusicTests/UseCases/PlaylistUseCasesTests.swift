//
//  PlaylistUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlaylistUseCasesTests: XCTestCase {

    private var sut: PlaylistUseCases!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockSongRepo: MockSongRepository!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockSongRepo = MockSongRepository()
        sut = PlaylistUseCases(
            playlistRepository: mockPlaylistRepo,
            songRepository: mockSongRepo
        )
    }

    override func tearDown() {
        sut = nil
        mockPlaylistRepo = nil
        mockSongRepo = nil
        super.tearDown()
    }

    // MARK: - getAllPlaylists()

    func test_getAllPlaylists_returnsAll() async throws {
        mockPlaylistRepo.playlists = [Playlist.make(name: "P1"), Playlist.make(name: "P2")]

        let result = try await sut.getAllPlaylists()

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - getMostPlayedPlaylists()

    func test_getMostPlayedPlaylists_sortsByTotalPlayCount() async throws {
        let lowSongs = [Song.make(playCount: 1), Song.make(playCount: 2)]
        let highSongs = [Song.make(playCount: 50), Song.make(playCount: 30)]
        mockPlaylistRepo.playlists = [
            Playlist.make(name: "Low", songs: lowSongs),
            Playlist.make(name: "High", songs: highSongs)
        ]

        let result = try await sut.getMostPlayedPlaylists(limit: 2)

        XCTAssertEqual(result.first?.name, "High")
    }

    func test_getMostPlayedPlaylists_respectsLimit() async throws {
        mockPlaylistRepo.playlists = (1...5).map { Playlist.make(name: "P\($0)") }

        let result = try await sut.getMostPlayedPlaylists(limit: 3)

        XCTAssertEqual(result.count, 3)
    }

    // MARK: - createPlaylist()

    func test_createPlaylist_callsRepository() async throws {
        _ = try await sut.createPlaylist(name: "My List", description: "desc", coverImageData: nil)

        XCTAssertEqual(mockPlaylistRepo.createCallCount, 1)
    }

    func test_createPlaylist_returnsPlaylistWithCorrectName() async throws {
        let result = try await sut.createPlaylist(name: "Rock", description: nil, coverImageData: nil)

        XCTAssertEqual(result.name, "Rock")
        XCTAssertTrue(result.songs.isEmpty)
    }

    // MARK: - renamePlaylist()

    func test_renamePlaylist_notFound_throwsError() async {
        do {
            try await sut.renamePlaylist(UUID(), newName: "New Name")
            XCTFail("Expected PlaylistError.notFound")
        } catch PlaylistError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_renamePlaylist_updatesName() async throws {
        let playlist = Playlist.make(name: "Old Name")
        mockPlaylistRepo.playlists = [playlist]

        try await sut.renamePlaylist(playlist.id, newName: "New Name")

        XCTAssertEqual(mockPlaylistRepo.updateCallCount, 1)
        XCTAssertEqual(mockPlaylistRepo.playlists.first?.name, "New Name")
    }

    // MARK: - updatePlaylist()

    func test_updatePlaylist_callsRepositoryUpdate() async throws {
        var playlist = Playlist.make(name: "Original")
        mockPlaylistRepo.playlists = [playlist]
        playlist = Playlist(
            id: playlist.id,
            name: "Updated",
            description: "New desc",
            songs: playlist.songs,
            coverImageData: nil,
            placeholderColorIndex: nil
        )

        try await sut.updatePlaylist(playlist)

        XCTAssertEqual(mockPlaylistRepo.updateCallCount, 1)
    }

    // MARK: - deletePlaylist()

    func test_deletePlaylist_callsRepository() async throws {
        let playlist = Playlist.make()
        mockPlaylistRepo.playlists = [playlist]

        try await sut.deletePlaylist(playlist.id)

        XCTAssertEqual(mockPlaylistRepo.deleteCallCount, 1)
        XCTAssertTrue(mockPlaylistRepo.playlists.isEmpty)
    }

    // MARK: - addSongToPlaylist()

    func test_addSong_songNotFound_throwsError() async {
        let playlist = Playlist.make()
        mockPlaylistRepo.playlists = [playlist]

        do {
            try await sut.addSongToPlaylist(songID: UUID(), playlistID: playlist.id)
            XCTFail("Expected PlaylistError.songNotFound")
        } catch PlaylistError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_addSong_songExists_callsRepository() async throws {
        let song = Song.make()
        let playlist = Playlist.make()
        mockSongRepo.songs = [song]
        mockPlaylistRepo.playlists = [playlist]

        try await sut.addSongToPlaylist(songID: song.id, playlistID: playlist.id)

        XCTAssertEqual(mockPlaylistRepo.addSongCallCount, 1)
    }

    // MARK: - getSongsInPlaylist()

    func test_getSongsInPlaylist_notFound_throwsError() async {
        do {
            _ = try await sut.getSongsInPlaylist(UUID())
            XCTFail("Expected PlaylistError.notFound")
        } catch PlaylistError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_getSongsInPlaylist_returnsSongs() async throws {
        let songs = [Song.make(title: "A"), Song.make(title: "B")]
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]

        let result = try await sut.getSongsInPlaylist(playlist.id)

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - clearPlaylist()

    func test_clearPlaylist_notFound_throwsError() async {
        do {
            try await sut.clearPlaylist(UUID())
            XCTFail("Expected PlaylistError.notFound")
        } catch PlaylistError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_clearPlaylist_removesAllSongs() async throws {
        let playlist = Playlist.make(songs: [Song.make(), Song.make()])
        mockPlaylistRepo.playlists = [playlist]

        try await sut.clearPlaylist(playlist.id)

        XCTAssertEqual(mockPlaylistRepo.updateCallCount, 1)
        XCTAssertTrue(mockPlaylistRepo.playlists.first?.songs.isEmpty ?? false)
    }

    // MARK: - getPlaylistStats()

    func test_getPlaylistStats_notFound_throwsError() async {
        do {
            _ = try await sut.getPlaylistStats(UUID())
            XCTFail("Expected PlaylistError.notFound")
        } catch PlaylistError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_getPlaylistStats_returnsCorrectCounts() async throws {
        let songs = [
            Song.make(isDownloaded: true, duration: 60, playCount: 5),
            Song.make(isDownloaded: false, duration: 120, playCount: 3)
        ]
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]

        let stats = try await sut.getPlaylistStats(playlist.id)

        XCTAssertEqual(stats.songCount, 2)
        XCTAssertEqual(stats.totalDuration, 180)
        XCTAssertEqual(stats.totalPlays, 8)
        XCTAssertEqual(stats.downloadedSongs, 1)
    }

    func test_playlistStats_formattedDuration_showsMinutesOnly() {
        let stats = PlaylistStats(songCount: 2, totalDuration: 150, totalPlays: 0, downloadedSongs: 0)
        XCTAssertEqual(stats.formattedDuration, "2 min")
    }

    func test_playlistStats_formattedDuration_showsHoursAndMinutes() {
        let stats = PlaylistStats(songCount: 1, totalDuration: 3661, totalPlays: 0, downloadedSongs: 0)
        XCTAssertEqual(stats.formattedDuration, "1h 1m")
    }

    // MARK: - getPlaylistByID()

    func test_getPlaylistByID_returnsNil_forUnknownID() async throws {
        let result = try await sut.getPlaylistByID(UUID())
        XCTAssertNil(result)
    }

    func test_getPlaylistByID_returnsCorrectPlaylist() async throws {
        let playlist = Playlist.make(name: "Jazz")
        mockPlaylistRepo.playlists = [playlist]

        let result = try await sut.getPlaylistByID(playlist.id)

        XCTAssertEqual(result?.name, "Jazz")
    }

    // MARK: - removeSongFromPlaylist()

    func test_removeSongFromPlaylist_callsRepository() async throws {
        let song = Song.make()
        let playlist = Playlist.make(songs: [song])
        mockPlaylistRepo.playlists = [playlist]

        try await sut.removeSongFromPlaylist(songID: song.id, playlistID: playlist.id)

        XCTAssertEqual(mockPlaylistRepo.removeSongCallCount, 1)
    }

    // MARK: - addSongsToPlaylist()

    func test_addSongsToPlaylist_addsAllSongs() async throws {
        let songs = [Song.make(), Song.make(), Song.make()]
        let playlist = Playlist.make()
        mockSongRepo.songs = songs
        mockPlaylistRepo.playlists = [playlist]

        try await sut.addSongsToPlaylist(songIDs: songs.map { $0.id }, playlistID: playlist.id)

        XCTAssertEqual(mockPlaylistRepo.addSongCallCount, 3)
    }

    func test_addSongsToPlaylist_stopsOnFirstSongNotFound() async {
        let song = Song.make()
        let playlist = Playlist.make()
        mockSongRepo.songs = [song]
        mockPlaylistRepo.playlists = [playlist]

        do {
            try await sut.addSongsToPlaylist(songIDs: [song.id, UUID()], playlistID: playlist.id)
            XCTFail("Expected PlaylistError.songNotFound")
        } catch PlaylistError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(mockPlaylistRepo.addSongCallCount, 1)
    }

    // MARK: - reorderSongs()

    func test_reorderSongs_notFound_throwsError() async {
        do {
            try await sut.reorderSongs(in: UUID(), fromOffsets: IndexSet([0]), toOffset: 1)
            XCTFail("Expected PlaylistError.notFound")
        } catch PlaylistError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_reorderSongs_callsRepositoryWithCorrectOrder() async throws {
        let songs = (0..<4).map { Song.make(title: "Song \($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]

        // Move last element to first position
        try await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([3]), toOffset: 0)

        XCTAssertEqual(mockPlaylistRepo.updateSongsOrderCallCount, 1)
        let order = mockPlaylistRepo.lastUpdatedSongsOrder
        XCTAssertEqual(order?[0], songs[3].id)
        XCTAssertEqual(order?[1], songs[0].id)
        XCTAssertEqual(order?[2], songs[1].id)
        XCTAssertEqual(order?[3], songs[2].id)
    }

    func test_reorderSongs_movingFirstToLast_producesCorrectOrder() async throws {
        let songs = (0..<3).map { Song.make(title: "S\($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]

        // Move first element to after the last (toOffset: 3 on a 3-element array)
        try await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([0]), toOffset: 3)

        let order = mockPlaylistRepo.lastUpdatedSongsOrder
        XCTAssertEqual(order?[0], songs[1].id)
        XCTAssertEqual(order?[1], songs[2].id)
        XCTAssertEqual(order?[2], songs[0].id)
    }
}
