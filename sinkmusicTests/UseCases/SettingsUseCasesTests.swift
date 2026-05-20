//
//  SettingsUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class SettingsUseCasesTests: XCTestCase {

    private var sut: SettingsUseCases!
    private var mockCredentials: MockCredentialsRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!

    override func setUp() {
        super.setUp()
        mockCredentials = MockCredentialsRepository()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        sut = SettingsUseCases(
            credentialsRepository: mockCredentials,
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockCredentials = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        super.tearDown()
    }

    // MARK: - saveGoogleDriveCredentials()

    func test_saveGoogleDrive_emptyAPIKey_returnsFalse() {
        let result = sut.saveGoogleDriveCredentials(apiKey: "", folderId: "some-folder-id-1234567890")
        XCTAssertFalse(result)
    }

    func test_saveGoogleDrive_emptyFolderID_returnsFalse() {
        let result = sut.saveGoogleDriveCredentials(apiKey: "AIzaSyBcD_exampleAPIKey1234567890", folderId: "")
        XCTAssertFalse(result)
    }

    func test_saveGoogleDrive_whitespaceOnly_returnsFalse() {
        let result = sut.saveGoogleDriveCredentials(apiKey: "   ", folderId: "  ")
        XCTAssertFalse(result)
    }

    func test_saveGoogleDrive_validData_returnsTrue() {
        let result = sut.saveGoogleDriveCredentials(
            apiKey: "AIzaSyBcD_exampleAPIKey1234567890",
            folderId: "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms"
        )
        XCTAssertTrue(result)
    }

    func test_saveGoogleDrive_trimsWhitespace() {
        _ = sut.saveGoogleDriveCredentials(
            apiKey: "  AIzaSyBcD_exampleAPIKey1234567890  ",
            folderId: "  folder123  "
        )

        XCTAssertEqual(mockCredentials.googleDriveAPIKey, "AIzaSyBcD_exampleAPIKey1234567890")
        XCTAssertEqual(mockCredentials.googleDriveFolderID, "folder123")
    }

    // MARK: - saveMegaFolderURL()

    func test_saveMega_invalidURL_returnsFalse() {
        let result = sut.saveMegaFolderURL("https://notmega.com/folder/abc")
        XCTAssertFalse(result)
    }

    func test_saveMega_validURLWithoutHash_returnsFalse() {
        let result = sut.saveMegaFolderURL("https://mega.nz/folder/abc123")
        XCTAssertFalse(result)
    }

    func test_saveMega_validURL_returnsTrue() {
        let result = sut.saveMegaFolderURL("https://mega.nz/folder/abc123#secretkey")
        XCTAssertTrue(result)
    }

    func test_saveMega_emptyString_returnsFalse() {
        let result = sut.saveMegaFolderURL("")
        XCTAssertFalse(result)
    }

    // MARK: - validateMegaFolderURL()

    func test_validateMega_correctFormat_returnsTrue() {
        XCTAssertTrue(sut.validateMegaFolderURL("https://mega.nz/folder/nodeId#key"))
    }

    func test_validateMega_missingHash_returnsFalse() {
        XCTAssertFalse(sut.validateMegaFolderURL("https://mega.nz/folder/nodeId"))
    }

    func test_validateMega_wrongDomain_returnsFalse() {
        XCTAssertFalse(sut.validateMegaFolderURL("https://googledrive.com/folder/nodeId#key"))
    }

    // MARK: - hasCurrentProviderCredentials()

    func test_hasCurrentProviderCredentials_googleDrive_checksGoogleCredentials() {
        mockCredentials.selectedProvider = .googleDrive
        mockCredentials.hasGoogleDriveCredentialsValue = true

        XCTAssertTrue(sut.hasCurrentProviderCredentials())
    }

    func test_hasCurrentProviderCredentials_mega_checksMegaCredentials() {
        mockCredentials.selectedProvider = .mega
        mockCredentials.hasMegaCredentialsValue = false

        XCTAssertFalse(sut.hasCurrentProviderCredentials())
    }

    // MARK: - setSelectedCloudProvider()

    func test_setSelectedProvider_updatesMock() {
        sut.setSelectedCloudProvider(.mega)

        XCTAssertEqual(mockCredentials.selectedProvider, .mega)
    }

    // MARK: - validateAPIKey() / validateFolderID()

    func test_validateAPIKey_shortKey_returnsFalse() {
        XCTAssertFalse(sut.validateAPIKey("short"))
    }

    func test_validateAPIKey_longEnoughKey_returnsTrue() {
        XCTAssertTrue(sut.validateAPIKey("AIzaSyBcDEFGHIJKLMNOPQRSTUVWXYZ1234567"))
    }

    func test_validateFolderID_shortID_returnsFalse() {
        XCTAssertFalse(sut.validateFolderID("short"))
    }

    func test_validateFolderID_validLength_returnsTrue() {
        XCTAssertTrue(sut.validateFolderID("1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE"))
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
    }

    // MARK: - getAppInfo()

    func test_getAppInfo_includesDisplayName() {
        let info = sut.getAppInfo()
        XCTAssertEqual(info.displayName, "SinkMusic")
    }

    func test_appInfo_fullVersion_combinesVersionAndBuild() {
        let info = AppInfo(version: "1.0.0", build: "19", displayName: "SinkMusic")
        XCTAssertEqual(info.fullVersion, "1.0.0 (19)")
    }
}
