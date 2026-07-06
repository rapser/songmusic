//
//  SettingsViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var sut: SettingsViewModel!
    private var mockCredentials: MockCredentialsRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockCloudStorage: MockCloudStorageRepository!
    private var mockMetadata: MockMetadataRepository!
    private var settingsUseCases: SettingsUseCases!
    private var downloadUseCases: DownloadUseCases!

    override func setUp() {
        super.setUp()
        mockCredentials = MockCredentialsRepository()
        mockSongRepo = MockSongRepository()
        mockCloudStorage = MockCloudStorageRepository()
        mockMetadata = MockMetadataRepository()
        settingsUseCases = SettingsUseCases(
            credentialsRepository: mockCredentials,
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage
        )
        downloadUseCases = DownloadUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: mockCloudStorage,
            metadataRepository: mockMetadata,
            credentialsRepository: mockCredentials,
            eventBus: MockEventBus()
        )
        sut = SettingsViewModel(
            settingsUseCases: settingsUseCases,
            downloadUseCases: downloadUseCases
        )
    }

    override func tearDown() {
        sut = nil
        settingsUseCases = nil
        downloadUseCases = nil
        mockCredentials = nil
        mockSongRepo = nil
        mockCloudStorage = nil
        mockMetadata = nil
        super.tearDown()
    }

    // MARK: - loadCredentials()

    func test_loadCredentials_setsApiKeyAndFolderID() {
        mockCredentials.googleDriveAPIKey = "test-api-key"
        mockCredentials.googleDriveFolderID = "test-folder"
        mockCredentials.hasGoogleDriveCredentialsValue = true

        sut.loadCredentials()

        XCTAssertEqual(sut.apiKey, "test-api-key")
        XCTAssertEqual(sut.folderId, "test-folder")
        XCTAssertTrue(sut.hasCredentials)
    }

    func test_loadCredentials_setsMegaFolderURL() {
        mockCredentials.megaFolderURL = "https://mega.nz/folder/abc123"
        mockCredentials.hasMegaCredentialsValue = true

        sut.loadCredentials()

        XCTAssertEqual(sut.megaFolderURL, "https://mega.nz/folder/abc123")
        XCTAssertTrue(sut.hasMegaCredentials)
    }

    func test_loadCredentials_setsSelectedProvider() {
        mockCredentials.selectedProvider = .mega

        sut.loadCredentials()

        XCTAssertEqual(sut.selectedProvider, .mega)
    }

    // MARK: - saveCredentials()

    func test_saveCredentials_validInput_setsHasCredentials() {
        sut.apiKey = "AIzaSyValidKey1234567890"
        sut.folderId = "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms"
        mockCredentials.saveGoogleDriveResult = true

        let result = sut.saveCredentials()

        XCTAssertTrue(result)
        XCTAssertTrue(sut.hasCredentials)
    }

    func test_saveCredentials_failure_doesNotSetHasCredentials() {
        sut.apiKey = "bad"
        sut.folderId = "bad"
        mockCredentials.saveGoogleDriveResult = false

        let result = sut.saveCredentials()

        XCTAssertFalse(result)
        XCTAssertFalse(sut.hasCredentials)
    }

    // MARK: - deleteCredentials()

    func test_deleteCredentials_clearsFields() {
        sut.apiKey = "some-key"
        sut.folderId = "some-folder"
        sut.hasCredentials = true

        sut.deleteCredentials()

        XCTAssertEqual(sut.apiKey, "")
        XCTAssertEqual(sut.folderId, "")
        XCTAssertFalse(sut.hasCredentials)
        XCTAssertEqual(mockCredentials.deleteGoogleDriveCallCount, 1)
    }

    // MARK: - testConnection()

    func test_testConnection_success_setsResultSuccess() async {
        mockCloudStorage.remoteFiles = [CloudFile.make(id: "f1")]

        await sut.testConnection()

        XCTAssertFalse(sut.isTestingConnection)
        XCTAssertTrue(sut.connectionTestResult?.isSuccess == true)
    }

    func test_testConnection_failure_setsResultFailure() async {
        mockCloudStorage.shouldThrowOnFetch = true

        await sut.testConnection()

        XCTAssertFalse(sut.isTestingConnection)
        XCTAssertFalse(sut.connectionTestResult?.isSuccess ?? true)
    }

    // MARK: - setSelectedProvider()

    func test_setSelectedProvider_updatesSelectedProvider() {
        sut.setSelectedProvider(.mega)

        XCTAssertEqual(sut.selectedProvider, .mega)
        XCTAssertEqual(mockCredentials.setProviderCallCount, 1)
    }

    // MARK: - saveMegaFolderURL()

    func test_saveMegaFolderURL_validURL_setsMegaCredentials() {
        sut.megaFolderURL = "https://mega.nz/folder/abc123#secretKey"
        mockCredentials.saveMegaResult = true

        let result = sut.saveMegaFolderURL()

        XCTAssertTrue(result)
        XCTAssertTrue(sut.hasMegaCredentials)
    }

    // MARK: - validateCredentials()

    func test_validateCredentials_emptyFields_returnsFalse() {
        sut.apiKey = ""
        sut.folderId = ""

        XCTAssertFalse(sut.validateCredentials())
    }

    // MARK: - hasCurrentProviderCredentials

    func test_hasCurrentProviderCredentials_googleDrive_withCredentials_returnsTrue() {
        sut.selectedProvider = .googleDrive
        sut.hasCredentials = true

        XCTAssertTrue(sut.hasCurrentProviderCredentials)
    }

    func test_hasCurrentProviderCredentials_mega_withoutCredentials_returnsFalse() {
        sut.selectedProvider = .mega
        sut.hasMegaCredentials = false

        XCTAssertFalse(sut.hasCurrentProviderCredentials)
    }
}
