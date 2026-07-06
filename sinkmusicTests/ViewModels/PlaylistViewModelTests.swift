//
//  PlaylistViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlaylistViewModelTests: XCTestCase {

    private var sut: PlaylistViewModel!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockReadStore: MockPlaylistReadStore!
    private var playlistUseCases: PlaylistUseCases!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockSongRepo = MockSongRepository()
        mockReadStore = MockPlaylistReadStore()
        playlistUseCases = PlaylistUseCases(
            playlistRepository: mockPlaylistRepo,
            songRepository: mockSongRepo
        )
        sut = PlaylistViewModel(playlistUseCases: playlistUseCases, readStore: mockReadStore)
    }

    override func tearDown() {
        sut = nil
        playlistUseCases = nil
        mockPlaylistRepo = nil
        mockSongRepo = nil
        mockReadStore = nil
        super.tearDown()
    }

    // MARK: - loadPlaylists()

    func test_loadPlaylists_populatesPlaylistsArray() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Rock"), Playlist.make(name: "Jazz")]

        await sut.loadPlaylists()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    // MARK: - createPlaylist()

    func test_createPlaylist_emptyName_doesNotCallRepository() async {
        do {
            _ = try await sut.createPlaylist(name: "   ", description: nil, coverImageData: nil)
        } catch {
            // PlaylistError.emptyName es el comportamiento esperado
        }

        XCTAssertEqual(mockPlaylistRepo.createCallCount, 0)
    }

    func test_createPlaylist_validName_callsRepositoryAndAddsToList() async throws {
        _ = try await sut.createPlaylist(name: "My Playlist", description: nil, coverImageData: nil)

        XCTAssertEqual(mockPlaylistRepo.createCallCount, 1)
    }

    // MARK: - renamePlaylist()

    func test_renamePlaylist_updatesName() async {
        let playlist = Playlist.make(name: "Old Name")
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        await sut.loadPlaylists()

        await sut.renamePlaylist(playlist.id, newName: "New Name")

        XCTAssertEqual(mockPlaylistRepo.updateCallCount, 1)
        XCTAssertEqual(mockPlaylistRepo.playlists.first?.name, "New Name")
    }

    // MARK: - deletePlaylist()

    func test_deletePlaylist_removesFromList() async {
        let playlist = Playlist.make()
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        await sut.loadPlaylists()

        await sut.deletePlaylist(playlist.id)

        XCTAssertEqual(mockPlaylistRepo.deleteCallCount, 1)
    }

    // MARK: - reorderSongs()

    func test_reorderSongs_optimisticUpdate_appliedImmediately() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        mockReadStore.songsInPlaylistValue = songs
        await sut.loadPlaylists()
        await sut.loadSongsInPlaylist(playlist.id)

        await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([0]), toOffset: 3)

        XCTAssertEqual(mockPlaylistRepo.updateSongsOrderCallCount, 1)
    }

    func test_reorderSongs_producesCorrectOrder() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        mockReadStore.songsInPlaylistValue = songs
        await sut.loadPlaylists()
        await sut.loadSongsInPlaylist(playlist.id)

        // Mover último elemento al principio
        await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([2]), toOffset: 0)

        let order = mockPlaylistRepo.lastUpdatedSongsOrder
        XCTAssertEqual(order?[0], songs[2].id)
        XCTAssertEqual(order?[1], songs[0].id)
        XCTAssertEqual(order?[2], songs[1].id)
    }

    // MARK: - addSongToPlaylist()

    func test_addSongToPlaylist_callsRepository() async {
        let song = Song.make()
        let playlist = Playlist.make()
        mockSongRepo.songs = [song]
        mockPlaylistRepo.playlists = [playlist]

        await sut.addSongToPlaylist(songID: song.id, playlistID: playlist.id)

        XCTAssertEqual(mockPlaylistRepo.addSongCallCount, 1)
    }

    // MARK: - ReadStore reactivity

    func test_readStoreChanges_reloadsPlaylists() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Initial")]
        await sut.loadPlaylists()
        mockReadStore.playlistsValue = [Playlist.make(name: "A"), Playlist.make(name: "B")]

        mockReadStore.simulateChange()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.playlists.count, 2)
    }
}
