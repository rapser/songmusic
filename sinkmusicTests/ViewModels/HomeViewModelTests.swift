//
//  HomeViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class HomeViewModelTests: XCTestCase {

    private var sut: HomeViewModel!
    private var mockReadStore: MockHomeReadStore!

    override func setUp() {
        super.setUp()
        mockReadStore = MockHomeReadStore()
        sut = HomeViewModel(readStore: mockReadStore)
    }

    override func tearDown() {
        sut = nil
        mockReadStore = nil
        super.tearDown()
    }

    // MARK: - loadData()

    func test_loadData_populatesPlaylists() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Rock"), Playlist.make(name: "Jazz")]

        await sut.loadData()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    func test_loadData_populatesRecentSongs() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)", lastPlayedAt: Date()) }
        mockReadStore.recentlyPlayedSongsValue = songs

        await sut.loadData()

        XCTAssertEqual(sut.recentSongs.count, 3)
    }

    func test_loadData_populatesDownloadedSongs() async {
        mockReadStore.downloadedSongsValue = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: true)
        ]

        await sut.loadData()

        XCTAssertEqual(sut.downloadedSongs.count, 2)
    }

    func test_loadData_setsIsLoadingFalseWhenDone() async {
        await sut.loadData()

        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - refresh()

    func test_refresh_reloadsAllData() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Initial")]
        await sut.loadData()
        mockReadStore.playlistsValue = [Playlist.make(name: "A"), Playlist.make(name: "B")]

        await sut.refresh()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    // MARK: - hasContent

    func test_hasContent_returnsFalse_whenEmpty() async {
        await sut.loadData()

        XCTAssertFalse(sut.hasContent)
    }

    func test_hasContent_returnsTrue_whenPlaylistsLoaded() async {
        mockReadStore.playlistsValue = [Playlist.make()]

        await sut.loadData()

        XCTAssertTrue(sut.hasContent)
    }

    // MARK: - ReadStore reactivity

    func test_readStoreChanges_reloadsData() async {
        mockReadStore.recentlyPlayedSongsValue = [Song.make(title: "Old", lastPlayedAt: Date())]
        await sut.loadData()
        mockReadStore.recentlyPlayedSongsValue = [
            Song.make(title: "A", lastPlayedAt: Date()),
            Song.make(title: "B", lastPlayedAt: Date())
        ]

        mockReadStore.simulateChange()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.recentSongs.count, 2)
    }
}
