//
//  DownloadUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class DownloadUseCasesTests: XCTestCase {

    private var sut: DownloadUseCases!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockMetadata: MockMetadataRepository!
    private var mockCredentials: MockCredentialsRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockMetadata = MockMetadataRepository()
        mockCredentials = MockCredentialsRepository()
        sut = DownloadUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            metadataRepository: mockMetadata,
            credentialsRepository: mockCredentials
        )
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockMetadata = nil
        mockCredentials = nil
        super.tearDown()
    }

    // MARK: - currentCloudProvider()

    func test_currentCloudProvider_delegatesToCredentialsRepository() {
        mockCredentials.selectedProvider = .mega
        XCTAssertEqual(sut.currentCloudProvider(), .mega)

        mockCredentials.selectedProvider = .googleDrive
        XCTAssertEqual(sut.currentCloudProvider(), .googleDrive)
    }

    // MARK: - downloadSong()

    func test_download_songNotFound_throwsError() async {
        do {
            try await sut.downloadSong(UUID())
            XCTFail("Expected DownloadError.songNotFound")
        } catch DownloadError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_download_alreadyDownloaded_throwsError() async {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]

        do {
            try await sut.downloadSong(song.id)
            XCTFail("Expected DownloadError.alreadyDownloaded")
        } catch DownloadError.alreadyDownloaded {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_download_success_marksAsDownloaded() async throws {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        try await sut.downloadSong(song.id)

        XCTAssertEqual(mockSongRepo.updateCallCount, 1)
        XCTAssertTrue(mockSongRepo.lastUpdatedSong?.isDownloaded == true)
    }

    func test_download_withMetadata_appliesExtractedTitle() async throws {
        let song = Song.make(title: "Original Title", isDownloaded: false)
        mockSongRepo.songs = [song]
        mockMetadata.metadata = SongMetadata(
            title: "Extracted Title",
            artist: "Extracted Artist",
            album: "Extracted Album",
            author: nil,
            duration: 210,
            artwork: nil,
            artworkThumbnail: nil,
            artworkMediumThumbnail: nil
        )

        try await sut.downloadSong(song.id)

        XCTAssertEqual(mockSongRepo.lastUpdatedSong?.title, "Extracted Title")
        XCTAssertEqual(mockSongRepo.lastUpdatedSong?.duration, 210)
    }

    func test_download_withEmptyMetadataTitle_keepsOriginalTitle() async throws {
        let song = Song.make(title: "Original Title", isDownloaded: false)
        mockSongRepo.songs = [song]
        mockMetadata.metadata = SongMetadata(
            title: "",
            artist: "",
            album: "",
            author: nil,
            duration: 180,
            artwork: nil,
            artworkThumbnail: nil,
            artworkMediumThumbnail: nil
        )

        try await sut.downloadSong(song.id)

        XCTAssertEqual(mockSongRepo.lastUpdatedSong?.title, "Original Title")
    }

    // MARK: - deleteDownload()

    func test_deleteDownload_songNotFound_throwsError() async {
        do {
            try await sut.deleteDownload(UUID())
            XCTFail("Expected DownloadError.songNotFound")
        } catch DownloadError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_deleteDownload_notDownloaded_throwsError() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        do {
            try await sut.deleteDownload(song.id)
            XCTFail("Expected DownloadError.notDownloaded")
        } catch DownloadError.notDownloaded {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_deleteDownload_success_marksAsNotDownloaded() async throws {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]

        try await sut.deleteDownload(song.id)

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 1)
        XCTAssertFalse(mockSongRepo.lastUpdatedSong?.isDownloaded == true)
    }

    // MARK: - isDownloaded()

    func test_isDownloaded_returnsTrue_forDownloadedSong() async throws {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]

        let result = try await sut.isDownloaded(song.id)

        XCTAssertTrue(result)
    }

    func test_isDownloaded_songNotFound_throwsError() async {
        do {
            _ = try await sut.isDownloaded(UUID())
            XCTFail("Expected DownloadError.songNotFound")
        } catch DownloadError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - getDownloadStats()

    func test_getDownloadStats_calculatesPercentageCorrectly() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true, duration: 60),
            Song.make(isDownloaded: true, duration: 120),
            Song.make(isDownloaded: false)
        ]

        let stats = try await sut.getDownloadStats()

        XCTAssertEqual(stats.totalDownloaded, 2)
        XCTAssertEqual(stats.totalSongs, 3)
        XCTAssertEqual(stats.downloadedDuration, 180)
        XCTAssertEqual(stats.downloadPercentage, 2.0 / 3.0 * 100.0, accuracy: 0.01)
    }

    func test_getDownloadStats_zeroDivision_returnsZeroPercentage() async throws {
        mockSongRepo.songs = []

        let stats = try await sut.getDownloadStats()

        XCTAssertEqual(stats.downloadPercentage, 0.0)
    }

    func test_downloadStats_formattedSize_showsMB() {
        let stats = DownloadStats(
            totalDownloaded: 10, totalSongs: 20,
            downloadedDuration: 0, estimatedSizeMB: 50.0
        )

        XCTAssertEqual(stats.formattedSize, "50 MB")
    }

    func test_downloadStats_formattedSize_showsGB() {
        let stats = DownloadStats(
            totalDownloaded: 300, totalSongs: 300,
            downloadedDuration: 0, estimatedSizeMB: 1500.0
        )

        XCTAssertTrue(stats.formattedSize.contains("GB"))
    }

    // MARK: - downloadSong() — rama sin metadata

    func test_download_withNilMetadata_usesDurationFromCloudStorage() async throws {
        let songID = UUID()
        let song = Song.make(id: songID, title: "Original", isDownloaded: false)
        mockSongRepo.songs = [song]
        // metadata = nil (default) → fallback a getDuration del CloudStorage
        let expectedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(songID.uuidString).m4a")
        mockCloudStorage.durations[expectedURL] = 240

        try await sut.downloadSong(songID)

        XCTAssertEqual(mockSongRepo.lastUpdatedSong?.duration, 240)
        XCTAssertEqual(mockSongRepo.lastUpdatedSong?.title, "Original")
        XCTAssertTrue(mockSongRepo.lastUpdatedSong?.isDownloaded == true)
    }

    func test_download_withNilMetadataAndNilDuration_marksAsDownloaded() async throws {
        let songID = UUID()
        let song = Song.make(id: songID, isDownloaded: false)
        mockSongRepo.songs = [song]
        // metadata = nil, durations dict vacío → getDuration retorna nil

        try await sut.downloadSong(songID)

        XCTAssertTrue(mockSongRepo.lastUpdatedSong?.isDownloaded == true)
        XCTAssertNil(mockSongRepo.lastUpdatedSong?.artworkData)
    }

    // MARK: - downloadMultipleSongs()

    func test_downloadMultipleSongs_downloadsAllSongs() async {
        let songs = [Song.make(isDownloaded: false), Song.make(isDownloaded: false)]
        mockSongRepo.songs = songs

        let result = await sut.downloadMultipleSongs(songs.map { $0.id })

        XCTAssertEqual(mockSongRepo.updateCallCount, 2)
        XCTAssertTrue(result.allSucceeded)
        XCTAssertEqual(result.successCount, 2)
    }

    func test_downloadMultipleSongs_partialFailure_reportsFailed() async {
        let goodSong = Song.make(isDownloaded: false)
        mockSongRepo.songs = [goodSong]

        let result = await sut.downloadMultipleSongs([goodSong.id, UUID()])

        XCTAssertEqual(mockSongRepo.updateCallCount, 1)
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failureCount, 1)
        XCTAssertTrue(result.hasFailures)
    }

    func test_downloadMultipleSongs_emptyList_makesNoCalls() async {
        let result = await sut.downloadMultipleSongs([])

        XCTAssertEqual(mockCloudStorage.downloadCallCount, 0)
        XCTAssertEqual(mockSongRepo.updateCallCount, 0)
        XCTAssertTrue(result.allSucceeded)
    }

    // MARK: - deleteAllDownloads()

    func test_deleteAllDownloads_deletesOnlyDownloadedSongs() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        try await sut.deleteAllDownloads()

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 2)
        XCTAssertEqual(mockSongRepo.updateCallCount, 2)
    }

    func test_deleteAllDownloads_emptyLibrary_makesNoCalls() async throws {
        mockSongRepo.songs = []

        try await sut.deleteAllDownloads()

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 0)
        XCTAssertEqual(mockSongRepo.updateCallCount, 0)
    }

    // MARK: - getLocalURL()

    func test_getLocalURL_delegatesToCloudStorage() {
        let songID = UUID()
        let url = URL(fileURLWithPath: "/tmp/\(songID).m4a")
        mockCloudStorage.downloadedURLs[songID] = url

        let result = sut.getLocalURL(for: songID)

        XCTAssertEqual(result, url)
    }

    func test_getLocalURL_returnsNil_whenNotDownloaded() {
        let result = sut.getLocalURL(for: UUID())
        XCTAssertNil(result)
    }
}
