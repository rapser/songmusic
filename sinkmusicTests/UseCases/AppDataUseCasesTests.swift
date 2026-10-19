//
//  AppDataUseCasesTests.swift
//  sinkmusicTests
//
//  Medición de tamaño y operaciones destructivas: lo que antes era la mitad de
//  `SettingsUseCasesTests`.
//

import XCTest
@testable import sinkmusic

@MainActor
final class AppDataUseCasesTests: XCTestCase {

    private var sut: AppDataUseCases!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockPlaylistRepo: MockPlaylistRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockPlaylistRepo = MockPlaylistRepository()
        sut = AppDataUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            playlistRepository: mockPlaylistRepo
        )
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockPlaylistRepo = nil
        super.tearDown()
    }

    // MARK: - getStorageInfo()

    func test_getStorageInfo_countsCorrectly() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true, artworkData: Data(repeating: 0, count: 1024 * 1024)),
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        let info = try await sut.getStorageInfo()

        XCTAssertEqual(info.totalSongs, 3)
        XCTAssertEqual(info.downloadedSongs, 2)
        XCTAssertGreaterThan(info.artworkSizeMB, 0)
    }

    /// El artwork sí se mide exacto: 1 MiB de datos son 1 MB en el informe.
    func test_getStorageInfo_artworkSizeIsMeasured_notEstimated() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: false, artworkData: Data(repeating: 0, count: 2 * 1024 * 1024))
        ]

        let info = try await sut.getStorageInfo()

        XCTAssertEqual(info.artworkSizeMB, 2, accuracy: 0.001)
    }

    /// El audio es una estimación por canción descargada, no una medida del disco.
    func test_getStorageInfo_audioSizeIsEstimatedPerDownloadedSong() async throws {
        mockSongRepo.songs = [Song.make(isDownloaded: true), Song.make(isDownloaded: false)]

        let info = try await sut.getStorageInfo()

        XCTAssertEqual(info.estimatedAudioSizeMB, 5)
        XCTAssertEqual(info.totalSizeMB, info.estimatedAudioSizeMB + info.artworkSizeMB)
    }

    func test_getStorageInfo_emptyLibrary_isAllZeros() async throws {
        mockSongRepo.songs = []

        let info = try await sut.getStorageInfo()

        XCTAssertEqual(info.totalSongs, 0)
        XCTAssertEqual(info.totalSizeMB, 0)
    }

    // MARK: - clearCache()

    func test_clearCache_clearsArtworkOfNonDownloadedSongs() async throws {
        let nonDownloaded = Song.make(isDownloaded: false, artworkData: Data([0xFF, 0xD8]))
        let downloaded = Song.make(isDownloaded: true, artworkData: Data([0xFF, 0xD8]))
        mockSongRepo.songs = [nonDownloaded, downloaded]

        try await sut.clearCache()

        XCTAssertEqual(mockSongRepo.updateCallCount, 1)
        XCTAssertNil(mockSongRepo.lastUpdatedSong?.artworkData)
        XCTAssertFalse(mockSongRepo.lastUpdatedSong?.isDownloaded ?? true)
    }

    /// Las descargadas conservan su artwork: la biblioteca offline debe seguir completa.
    func test_clearCache_doesNotTouchDownloadedSongs() async throws {
        mockSongRepo.songs = [Song.make(isDownloaded: true, artworkData: Data([0x01]))]

        try await sut.clearCache()

        XCTAssertEqual(mockSongRepo.updateCallCount, 0)
    }

    func test_clearCache_emptyLibrary_makesNoCalls() async throws {
        mockSongRepo.songs = []

        try await sut.clearCache()

        XCTAssertEqual(mockSongRepo.updateCallCount, 0)
    }

    // MARK: - deleteAllSongs()

    func test_deleteAllSongs_deletesFilesAndDBRecords() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        try await sut.deleteAllSongs()

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 2)
        XCTAssertEqual(mockSongRepo.deleteCallCount, 3)
        XCTAssertTrue(mockSongRepo.songs.isEmpty)
    }

    func test_deleteAllSongs_emptyLibrary_makesNoCalls() async throws {
        mockSongRepo.songs = []

        try await sut.deleteAllSongs()

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 0)
        XCTAssertEqual(mockSongRepo.deleteCallCount, 0)
    }

    /// Las playlists sobreviven, pero vacías: no deben apuntar a canciones que ya no están.
    func test_deleteAllSongs_removesEachSongFromAllPlaylists() async throws {
        mockSongRepo.songs = [Song.make(isDownloaded: true), Song.make(isDownloaded: false)]

        try await sut.deleteAllSongs()

        XCTAssertEqual(mockPlaylistRepo.removeSongFromAllPlaylistsCallCount, 2)
    }

    func test_deleteAllSongs_onlyCallsCloudDeleteForDownloadedSongs() async throws {
        mockSongRepo.songs = [Song.make(isDownloaded: false), Song.make(isDownloaded: false)]

        try await sut.deleteAllSongs()

        XCTAssertEqual(mockCloudStorage.deleteDownloadCallCount, 0)
        XCTAssertEqual(mockSongRepo.deleteCallCount, 2)
    }

    // MARK: - StorageInfo

    func test_storageInfo_formattedSize_showsMB() {
        let info = StorageInfo(
            totalSongs: 5, downloadedSongs: 5,
            estimatedAudioSizeMB: 25, artworkSizeMB: 2,
            totalSizeMB: 27
        )

        XCTAssertEqual(info.formattedTotalSize, "27 MB")
    }

    func test_storageInfo_formattedSize_showsGB() {
        let info = StorageInfo(
            totalSongs: 300, downloadedSongs: 300,
            estimatedAudioSizeMB: 1500, artworkSizeMB: 100,
            totalSizeMB: 1600
        )

        XCTAssertTrue(info.formattedTotalSize.contains("GB"))
        XCTAssertTrue(info.formattedAudioSize.contains("GB"))
    }
}
