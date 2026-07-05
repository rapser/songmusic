//
//  LibraryViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class LibraryViewModelTests: XCTestCase {

    private var sut: LibraryViewModel!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockCredentials: MockCredentialsRepository!
    private var mockReadStore: MockLibraryReadStore!
    private var libraryUseCases: LibraryUseCases!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockCredentials = MockCredentialsRepository()
        mockReadStore = MockLibraryReadStore()
        libraryUseCases = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            credentialsRepository: mockCredentials
        )
        sut = LibraryViewModel(libraryUseCases: libraryUseCases, readStore: mockReadStore)
    }

    override func tearDown() {
        sut = nil
        libraryUseCases = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockCredentials = nil
        mockReadStore = nil
        super.tearDown()
    }

    // MARK: - loadSongs()

    func test_loadSongs_populatesSongsArray() async {
        mockReadStore.songsValue = [Song.make(title: "A"), Song.make(title: "B")]

        await sut.loadSongs()

        XCTAssertEqual(sut.songs.count, 2)
    }

    func test_loadSongs_emptyLibrary_producesEmptySongs() async {
        mockReadStore.songsValue = []

        await sut.loadSongs()

        XCTAssertTrue(sut.songs.isEmpty)
    }

    // MARK: - syncLibraryWithCatalog()

    func test_sync_noCredentials_abortsSilentlyWithNoError() async {
        mockCredentials.hasGoogleDriveCredentialsValue = false
        mockCredentials.selectedProvider = .googleDrive

        await sut.syncLibraryWithCatalog()

        XCTAssertNil(sut.syncError)
        XCTAssertEqual(mockCloudStorage.fetchCallCount, 0)
    }

    func test_sync_success_addsNewSongs() async {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        mockCloudStorage.remoteFiles = [CloudFile.make(id: "f1"), CloudFile.make(id: "f2")]
        mockSongRepo.songs = []

        await sut.syncLibraryWithCatalog()

        XCTAssertEqual(mockSongRepo.createCallCount, 2)
        XCTAssertNil(sut.syncError)
    }

    func test_sync_fetchError_setsInvalidCredentials() async {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        mockCloudStorage.shouldThrowOnFetch = true

        await sut.syncLibraryWithCatalog()

        XCTAssertNotNil(sut.syncError)
    }

    // MARK: - deleteSong()

    func test_deleteSong_removesFromLocalList() async {
        let song = Song.make()
        mockSongRepo.songs = [song]
        mockReadStore.songsValue = [song]
        await sut.loadSongs()

        await sut.deleteSong(song.id)

        XCTAssertEqual(mockSongRepo.deleteCallCount, 1)
    }

    // MARK: - hasCredentials()

    func test_hasCredentials_returnsTrue_whenConfigured() {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        mockCredentials.selectedProvider = .googleDrive

        XCTAssertTrue(sut.hasCredentials())
    }

    func test_hasCredentials_returnsFalse_whenNotConfigured() {
        mockCredentials.hasGoogleDriveCredentialsValue = false
        mockCredentials.selectedProvider = .googleDrive

        XCTAssertFalse(sut.hasCredentials())
    }

    // MARK: - ReadStore reactivity

    func test_readStoreChanges_reloadsLibrary() async {
        mockReadStore.songsValue = [Song.make(title: "Z")]
        await sut.loadSongs()
        mockReadStore.songsValue = [Song.make(title: "A"), Song.make(title: "B")]

        mockReadStore.simulateChange()
        // Dar tiempo al Task interno de procesar la señal
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.songs.count, 2)
    }

    func test_readStoreChanges_alsoReloadsStats() async {
        mockReadStore.songsValue = [Song.make(title: "Old")]
        mockReadStore.statsValue = LibraryStats(
            totalSongs: 1, downloadedSongs: 0, totalDuration: 0, totalPlays: 1, uniqueArtists: 1, uniqueAlbums: 0
        )
        await sut.loadSongs()
        await sut.loadStats()

        mockReadStore.statsValue = LibraryStats(
            totalSongs: 2, downloadedSongs: 0, totalDuration: 0, totalPlays: 99, uniqueArtists: 1, uniqueAlbums: 0
        )
        mockReadStore.simulateChange()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.libraryStats?.totalPlays, 99)
    }
}
