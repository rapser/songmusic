//
//  DownloadViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class DownloadViewModelTests: XCTestCase {

    private var sut: DownloadViewModel!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockMetadata: MockMetadataRepository!
    private var mockCredentials: MockCredentialsRepository!
    private var mockEventBus: MockEventBus!
    private var downloadUseCases: DownloadUseCases!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockMetadata = MockMetadataRepository()
        mockCredentials = MockCredentialsRepository()
        mockEventBus = MockEventBus()
        downloadUseCases = DownloadUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            metadataRepository: mockMetadata,
            credentialsRepository: mockCredentials,
            eventBus: mockEventBus
        )
        sut = DownloadViewModel(downloadUseCases: downloadUseCases, eventBus: mockEventBus)
    }

    override func tearDown() {
        sut = nil
        downloadUseCases = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockMetadata = nil
        mockCredentials = nil
        mockEventBus = nil
        super.tearDown()
    }

    // MARK: - download()

    func test_download_songNotFound_setsDownloadError() async {
        await sut.download(songID: UUID())

        XCTAssertNotNil(sut.downloadError)
    }

    func test_download_alreadyDownloaded_setsError() async {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]

        await sut.download(songID: song.id)

        XCTAssertNotNil(sut.downloadError)
    }

    func test_download_success_callsCloudStorage() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        await sut.download(songID: song.id)

        XCTAssertEqual(mockCloudStorage.downloadCallCount, 1)
    }

    func test_download_success_marksAsDownloaded() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        await sut.download(songID: song.id)

        XCTAssertEqual(mockSongRepo.updateCallCount, 1)
        XCTAssertTrue(mockSongRepo.lastUpdatedSong?.isDownloaded == true)
    }

    // MARK: - deleteDownload()

    func test_deleteDownload_success_callsCloudStorageDelete() async {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]

        await sut.deleteDownload(songID: song.id)

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 1)
    }

    func test_deleteDownload_notDownloaded_setsError() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        await sut.deleteDownload(songID: song.id)

        XCTAssertNotNil(sut.downloadError)
    }

    // MARK: - isDownloading()

    func test_isDownloading_returnsFalse_whenNotActive() {
        XCTAssertFalse(sut.isDownloading(songID: UUID()))
    }

    // MARK: - progress()

    func test_progress_returnsNil_whenNoDownloadActive() {
        XCTAssertNil(sut.progress(for: UUID()))
    }

    // MARK: - EventBus reactions

    func test_eventBus_progress_updatesProgressDict() async {
        let songID = UUID()
        let song = Song.make(id: songID, isDownloaded: false)
        mockSongRepo.songs = [song]
        // Iniciar la tarea para que haya un Task registrado
        let downloadTask = Task { await sut.download(songID: songID) }

        // Dar tiempo al Task de registrarse
        try? await Task.sleep(for: .milliseconds(10))
        mockEventBus.emit(.progress(songID: songID, progress: 0.5))
        try? await Task.sleep(for: .milliseconds(50))

        downloadTask.cancel()
    }

    func test_eventBus_quotaExceeded_showsAlert() async {
        let resetDate = Date(timeIntervalSinceNow: 3600)
        mockEventBus.emit(.quotaExceeded(provider: "mega", resetTime: resetDate))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(sut.showQuotaAlert)
        XCTAssertNotNil(sut.quotaResetTime)
    }

    // MARK: - dismissQuotaAlert()

    func test_dismissQuotaAlert_hidesAlert() async {
        let resetDate = Date(timeIntervalSinceNow: 3600)
        mockEventBus.emit(.quotaExceeded(provider: "mega", resetTime: resetDate))
        try? await Task.sleep(for: .milliseconds(50))

        sut.dismissQuotaAlert()

        XCTAssertFalse(sut.showQuotaAlert)
    }

    // MARK: - clearDownloadError()

    func test_clearDownloadError_removesError() async {
        await sut.download(songID: UUID())
        XCTAssertNotNil(sut.downloadError)

        sut.clearDownloadError()

        XCTAssertNil(sut.downloadError)
    }
}
