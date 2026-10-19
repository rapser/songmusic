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
    private var queueManager: DownloadQueueManager!

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
        queueManager = DownloadQueueManager()
        sut = DownloadViewModel(
            downloadUseCases: downloadUseCases,
            eventBus: mockEventBus,
            bulkReloadGate: ReactiveReloadGate([]),
            queueManager: queueManager
        )
    }

    override func tearDown() {
        sut = nil
        queueManager = nil
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

    /// El camino real: Mega devuelve un rate limit durante la descarga.
    ///
    /// Antes esto se probaba emitiendo `.quotaExceeded` en el bus, un evento que el propio
    /// ViewModel emitía y consumía. Al quitar ese round-trip, el test pasa a ejercitar lo
    /// que de verdad ocurre.
    func test_download_whenMegaRateLimits_showsAlertAndRemembersTheBackoff() async {
        mockCredentials.selectedProvider = .mega
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]
        mockCloudStorage.errorOnDownload = MegaError.rateLimitExceeded(retryAfter: 1800)

        await sut.download(songID: song.id)

        XCTAssertTrue(sut.showQuotaAlert)
        XCTAssertEqual(sut.quotaExceededProvider, .mega)
        XCTAssertNotNil(sut.quotaResetTime)
        XCTAssertNotNil(sut.downloadError)
        let backoffIsShared = await queueManager.isQuotaExceeded(for: .mega)
        XCTAssertTrue(backoffIsShared, "El backoff queda en la cola compartida, no solo en la pantalla")
    }

    // MARK: - dismissQuotaAlert()

    /// La cola se inyecta, así que el backoff por cuota vive fuera del ViewModel: una
    /// pantalla nueva sigue sabiendo que el proveedor está limitado y no reintenta.
    /// Cuando la cola se creaba dentro del ViewModel, recrearlo borraba ese estado.
    func test_quotaBackoff_survivesANewViewModel() async {
        await queueManager.markQuotaExceeded(provider: .googleDrive, retryAfter: 3600)

        let recreated = DownloadViewModel(
            downloadUseCases: downloadUseCases,
            eventBus: mockEventBus,
            bulkReloadGate: ReactiveReloadGate([]),
            queueManager: queueManager
        )

        await recreated.download(songID: UUID())

        XCTAssertTrue(recreated.showQuotaAlert)
        XCTAssertEqual(recreated.quotaExceededProvider, .googleDrive)
        XCTAssertFalse(recreated.isDownloading, "No debe intentar la descarga con la cuota excedida")
    }

    func test_dismissQuotaAlert_hidesAlert() async {
        await queueManager.markQuotaExceeded(provider: .googleDrive, retryAfter: 3600)
        await sut.download(songID: UUID())
        XCTAssertTrue(sut.showQuotaAlert)

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
