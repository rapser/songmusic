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
    private var mockEventBus: MockEventBus!
    private var libraryUseCases: LibraryUseCases!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockCredentials = MockCredentialsRepository()
        mockEventBus = MockEventBus()
        libraryUseCases = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            credentialsRepository: mockCredentials
        )
        sut = LibraryViewModel(libraryUseCases: libraryUseCases, eventBus: mockEventBus)
    }

    override func tearDown() {
        sut = nil
        libraryUseCases = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockCredentials = nil
        mockEventBus = nil
        super.tearDown()
    }

    // MARK: - loadSongs()

    func test_loadSongs_populatesSongsArray() async {
        mockSongRepo.songs = [Song.make(title: "A"), Song.make(title: "B")]

        await sut.loadSongs()

        XCTAssertEqual(sut.songs.count, 2)
    }

    func test_loadSongs_emptyLibrary_producesEmptySongs() async {
        mockSongRepo.songs = []

        await sut.loadSongs()

        XCTAssertTrue(sut.songs.isEmpty)
    }

    // MARK: - syncLibraryWithCatalog()

    func test_sync_noCredentials_setsInvalidCredentialsError() async {
        mockCredentials.hasGoogleDriveCredentialsValue = false
        mockCredentials.selectedProvider = .googleDrive

        await sut.syncLibraryWithCatalog()

        XCTAssertEqual(sut.syncError, .invalidCredentials)
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

    // MARK: - EventBus reaction

    func test_eventBus_songsUpdated_reloadsLibrary() async {
        mockSongRepo.songs = [Song.make(title: "Z")]
        await sut.loadSongs()
        mockSongRepo.songs = [Song.make(title: "A"), Song.make(title: "B")]

        mockEventBus.emit(.songsUpdated)
        // Dar tiempo al Task interno de procesar el evento
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.songs.count, 2)
    }
}
