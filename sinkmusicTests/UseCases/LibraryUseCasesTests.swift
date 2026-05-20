//
//  LibraryUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class LibraryUseCasesTests: XCTestCase {

    private var sut: LibraryUseCases!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockCredentials: MockCredentialsRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockCredentials = MockCredentialsRepository()
        sut = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            credentialsRepository: mockCredentials
        )
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockCredentials = nil
        super.tearDown()
    }

    // MARK: - getAllSongs()

    func test_getAllSongs_returnsAllSongs() async throws {
        let songs = [Song.make(title: "A"), Song.make(title: "B")]
        mockSongRepo.songs = songs

        let result = try await sut.getAllSongs()

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - getRecentlyPlayedSongs()

    func test_getRecentlyPlayedSongs_sortsByDateDescending() async throws {
        let older = Song.make(title: "Older", lastPlayedAt: Date(timeIntervalSinceNow: -200))
        let newer = Song.make(title: "Newer", lastPlayedAt: Date(timeIntervalSinceNow: -10))
        let never = Song.make(title: "Never", lastPlayedAt: nil)
        mockSongRepo.songs = [older, newer, never]

        let result = try await sut.getRecentlyPlayedSongs(limit: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "Newer")
    }

    func test_getRecentlyPlayedSongs_respectsLimit() async throws {
        mockSongRepo.songs = (1...5).map {
            Song.make(title: "Song \($0)", lastPlayedAt: Date(timeIntervalSinceNow: Double(-$0)))
        }

        let result = try await sut.getRecentlyPlayedSongs(limit: 3)

        XCTAssertEqual(result.count, 3)
    }

    // MARK: - getMostPlayedSongs()

    func test_getMostPlayedSongs_delegatesToRepository() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Low", playCount: 1),
            Song.make(title: "High", playCount: 99)
        ]

        let result = try await sut.getMostPlayedSongs(limit: 1)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "High")
    }

    // MARK: - syncWithCloudStorage()

    func test_sync_noCredentials_throwsError() async {
        mockCredentials.selectedProvider = .googleDrive
        mockCredentials.hasGoogleDriveCredentialsValue = false

        do {
            _ = try await sut.syncWithCloudStorage()
            XCTFail("Expected LibraryError.credentialsNotConfigured")
        } catch LibraryError.credentialsNotConfigured {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_sync_addsNewRemoteSongs() async throws {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        mockCloudStorage.remoteFiles = [
            CloudFile.make(id: "remote-1"),
            CloudFile.make(id: "remote-2")
        ]
        mockSongRepo.songs = []

        let added = try await sut.syncWithCloudStorage()

        XCTAssertEqual(added, 2)
        XCTAssertEqual(mockSongRepo.createCallCount, 2)
    }

    func test_sync_skipsAlreadyLocalSongs() async throws {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        mockCloudStorage.remoteFiles = [CloudFile.make(id: "file-id")]
        mockSongRepo.songs = [Song.make(fileID: "file-id")]

        let added = try await sut.syncWithCloudStorage()

        XCTAssertEqual(added, 0)
        XCTAssertEqual(mockSongRepo.createCallCount, 0)
    }

    // MARK: - deleteSong()

    func test_deleteSong_callsRepositoryDelete() async throws {
        let song = Song.make()
        mockSongRepo.songs = [song]

        try await sut.deleteSong(song.id)

        XCTAssertEqual(mockSongRepo.deleteCallCount, 1)
        XCTAssertEqual(mockSongRepo.lastDeletedID, song.id)
    }

    func test_deleteSongs_deletesAll() async throws {
        let songs = [Song.make(), Song.make()]
        mockSongRepo.songs = songs

        try await sut.deleteSongs(songs.map { $0.id })

        XCTAssertEqual(mockSongRepo.deleteCallCount, 2)
    }

    // MARK: - getLibraryStats()

    func test_getLibraryStats_countsCorrectly() async throws {
        mockSongRepo.songs = [
            Song.make(artist: "Artist A", album: "Album 1", isDownloaded: true, duration: 60, playCount: 3),
            Song.make(artist: "Artist A", album: "Album 2", isDownloaded: false, duration: 120, playCount: 1),
            Song.make(artist: "Artist B", album: nil, isDownloaded: true, duration: 90, playCount: 0)
        ]

        let stats = try await sut.getLibraryStats()

        XCTAssertEqual(stats.totalSongs, 3)
        XCTAssertEqual(stats.downloadedSongs, 2)
        XCTAssertEqual(stats.totalDuration, 270)
        XCTAssertEqual(stats.totalPlays, 4)
        XCTAssertEqual(stats.uniqueArtists, 2)
        XCTAssertEqual(stats.uniqueAlbums, 2)
    }

    func test_libraryStats_formattedDuration_showsHoursAndMinutes() {
        let stats = LibraryStats(
            totalSongs: 1, downloadedSongs: 1,
            totalDuration: 3661, totalPlays: 0,
            uniqueArtists: 1, uniqueAlbums: 1
        )

        XCTAssertEqual(stats.formattedDuration, "1h 1m")
    }

    // MARK: - hasCredentials()

    func test_hasCredentials_googleDrive_returnsTrueWhenSet() {
        mockCredentials.selectedProvider = .googleDrive
        mockCredentials.hasGoogleDriveCredentialsValue = true

        XCTAssertTrue(sut.hasCredentials())
    }

    func test_hasCredentials_mega_returnsFalseWhenNotSet() {
        mockCredentials.selectedProvider = .mega
        mockCredentials.hasMegaCredentialsValue = false

        XCTAssertFalse(sut.hasCredentials())
    }
}
