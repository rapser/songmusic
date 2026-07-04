//
//  HomeViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class HomeViewModelTests: XCTestCase {

    private var sut: HomeViewModel!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockCredentials: MockCredentialsRepository!
    private var mockEventBus: MockEventBus!
    private var playlistUseCases: PlaylistUseCases!
    private var libraryUseCases: LibraryUseCases!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockCredentials = MockCredentialsRepository()
        mockEventBus = MockEventBus()
        playlistUseCases = PlaylistUseCases(
            playlistRepository: mockPlaylistRepo,
            songRepository: mockSongRepo
        )
        libraryUseCases = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            credentialsRepository: mockCredentials
        )
        sut = HomeViewModel(
            playlistUseCases: playlistUseCases,
            libraryUseCases: libraryUseCases,
            eventBus: mockEventBus
        )
    }

    override func tearDown() {
        sut = nil
        playlistUseCases = nil
        libraryUseCases = nil
        mockPlaylistRepo = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockCredentials = nil
        mockEventBus = nil
        super.tearDown()
    }

    // MARK: - loadData()

    func test_loadData_populatesPlaylists() async {
        mockPlaylistRepo.playlists = [Playlist.make(name: "Rock"), Playlist.make(name: "Jazz")]

        await sut.loadData()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    func test_loadData_populatesRecentSongs() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)", lastPlayedAt: Date()) }
        mockSongRepo.songs = songs

        await sut.loadData()

        XCTAssertEqual(sut.recentSongs.count, 3)
    }

    func test_loadData_populatesDownloadedSongs() async {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false),
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
        mockPlaylistRepo.playlists = [Playlist.make(name: "Initial")]
        await sut.loadData()
        mockPlaylistRepo.playlists = [Playlist.make(name: "A"), Playlist.make(name: "B")]

        await sut.refresh()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    // MARK: - hasContent

    func test_hasContent_returnsFalse_whenEmpty() async {
        mockPlaylistRepo.playlists = []
        mockSongRepo.songs = []

        await sut.loadData()

        XCTAssertFalse(sut.hasContent)
    }

    func test_hasContent_returnsTrue_whenPlaylistsLoaded() async {
        mockPlaylistRepo.playlists = [Playlist.make()]

        await sut.loadData()

        XCTAssertTrue(sut.hasContent)
    }

    // MARK: - EventBus reactions

    func test_eventBus_songsUpdated_reloadsRecentSongs() async {
        mockSongRepo.songs = [Song.make(title: "Old", lastPlayedAt: Date())]
        await sut.loadData()
        mockSongRepo.songs = [Song.make(title: "A", lastPlayedAt: Date()), Song.make(title: "B", lastPlayedAt: Date())]

        mockEventBus.emit(.songsUpdated)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.recentSongs.count, 2)
    }

    func test_eventBus_playlistsUpdated_reloadsPlaylists() async {
        mockPlaylistRepo.playlists = [Playlist.make(name: "Old")]
        await sut.loadData()
        mockPlaylistRepo.playlists = [Playlist.make(name: "A"), Playlist.make(name: "B"), Playlist.make(name: "C")]

        mockEventBus.emit(.playlistsUpdated)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.playlists.count, 3)
    }

    func test_eventBus_songDownloaded_reloadsDownloadedSongs() async {
        mockSongRepo.songs = [Song.make(isDownloaded: true)]
        await sut.loadData()
        mockSongRepo.songs = [Song.make(isDownloaded: true), Song.make(isDownloaded: true)]

        mockEventBus.emit(.songDownloaded(UUID()))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.downloadedSongs.count, 2)
    }
}
