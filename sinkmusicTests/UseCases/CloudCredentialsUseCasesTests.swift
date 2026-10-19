//
//  CloudCredentialsUseCasesTests.swift
//  sinkmusicTests
//
//  Antes era parte de `SettingsUseCasesTests`, que montaba cuatro repositorios para
//  probar cualquier cosa. Aquí bastan dos.
//

import XCTest
@testable import sinkmusic

@MainActor
final class CloudCredentialsUseCasesTests: XCTestCase {

    private var sut: CloudCredentialsUseCases!
    private var mockCredentials: MockCredentialsRepository!
    private var mockCloudStorage: MockCloudStorageRepository!

    override func setUp() {
        super.setUp()
        mockCredentials = MockCredentialsRepository()
        mockCloudStorage = MockCloudStorageRepository()
        sut = CloudCredentialsUseCases(
            credentialsRepository: mockCredentials,
            cloudStorageRepository: mockCloudStorage
        )
    }

    override func tearDown() {
        sut = nil
        mockCredentials = nil
        mockCloudStorage = nil
        super.tearDown()
    }

    // MARK: - saveGoogleDriveCredentials()

    func test_saveGoogleDrive_emptyAPIKey_returnsFalse() {
        XCTAssertFalse(sut.saveGoogleDriveCredentials(apiKey: "", folderId: "some-folder-id-1234567890"))
    }

    func test_saveGoogleDrive_emptyFolderID_returnsFalse() {
        XCTAssertFalse(sut.saveGoogleDriveCredentials(apiKey: "AIzaSyBcD_exampleAPIKey1234567890", folderId: ""))
    }

    func test_saveGoogleDrive_whitespaceOnly_returnsFalse() {
        XCTAssertFalse(sut.saveGoogleDriveCredentials(apiKey: "   ", folderId: "  "))
    }

    func test_saveGoogleDrive_validData_returnsTrue() {
        XCTAssertTrue(sut.saveGoogleDriveCredentials(
            apiKey: "AIzaSyBcD_exampleAPIKey1234567890",
            folderId: "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms"
        ))
    }

    func test_saveGoogleDrive_trimsWhitespace() {
        _ = sut.saveGoogleDriveCredentials(
            apiKey: "  AIzaSyBcD_exampleAPIKey1234567890  ",
            folderId: "  folder123  "
        )

        XCTAssertEqual(mockCredentials.googleDriveAPIKey, "AIzaSyBcD_exampleAPIKey1234567890")
        XCTAssertEqual(mockCredentials.googleDriveFolderID, "folder123")
    }

    // MARK: - loadGoogleDriveCredentials()

    func test_loadGoogleDriveCredentials_returnsStoredValues() {
        mockCredentials.googleDriveAPIKey = "myAPIKey"
        mockCredentials.googleDriveFolderID = "myFolderID"
        mockCredentials.hasGoogleDriveCredentialsValue = true

        let result = sut.loadGoogleDriveCredentials()

        XCTAssertEqual(result.apiKey, "myAPIKey")
        XCTAssertEqual(result.folderId, "myFolderID")
        XCTAssertTrue(result.hasCredentials)
    }

    func test_hasGoogleDriveCredentials_delegatesToRepository() {
        mockCredentials.hasGoogleDriveCredentialsValue = true
        XCTAssertTrue(sut.hasGoogleDriveCredentials())

        mockCredentials.hasGoogleDriveCredentialsValue = false
        XCTAssertFalse(sut.hasGoogleDriveCredentials())
    }

    func test_deleteGoogleDriveCredentials_clearsCredentials() {
        mockCredentials.hasGoogleDriveCredentialsValue = true

        sut.deleteGoogleDriveCredentials()

        XCTAssertFalse(mockCredentials.hasGoogleDriveCredentials())
        XCTAssertEqual(mockCredentials.googleDriveAPIKey, "")
    }

    // MARK: - saveMegaFolderURL()

    func test_saveMega_invalidURL_returnsFalse() {
        XCTAssertFalse(sut.saveMegaFolderURL("https://notmega.com/folder/abc"))
    }

    func test_saveMega_validURLWithoutHash_returnsFalse() {
        XCTAssertFalse(sut.saveMegaFolderURL("https://mega.nz/folder/abc123"))
    }

    func test_saveMega_validURL_returnsTrue() {
        XCTAssertTrue(sut.saveMegaFolderURL("https://mega.nz/folder/abc123#secretkey"))
    }

    func test_saveMega_emptyString_returnsFalse() {
        XCTAssertFalse(sut.saveMegaFolderURL(""))
    }

    func test_loadMegaFolderURL_returnsStoredValue() {
        mockCredentials.megaFolderURL = "https://mega.nz/folder/abc#key"

        XCTAssertEqual(sut.loadMegaFolderURL(), "https://mega.nz/folder/abc#key")
    }

    func test_hasMegaCredentials_delegatesToRepository() {
        mockCredentials.hasMegaCredentialsValue = true
        XCTAssertTrue(sut.hasMegaCredentials())

        mockCredentials.hasMegaCredentialsValue = false
        XCTAssertFalse(sut.hasMegaCredentials())
    }

    func test_deleteMegaCredentials_clearsCredentials() {
        mockCredentials.hasMegaCredentialsValue = true

        sut.deleteMegaCredentials()

        XCTAssertFalse(mockCredentials.hasMegaCredentials())
        XCTAssertEqual(mockCredentials.megaFolderURL, "")
    }

    // MARK: - validateMegaFolderURL()

    func test_validateMega_correctFormat_returnsTrue() {
        XCTAssertTrue(sut.validateMegaFolderURL("https://mega.nz/folder/nodeId#key"))
    }

    /// Sin fragmento no hay clave de descifrado: la carpeta no se podría leer.
    func test_validateMega_missingHash_returnsFalse() {
        XCTAssertFalse(sut.validateMegaFolderURL("https://mega.nz/folder/nodeId"))
    }

    func test_validateMega_wrongDomain_returnsFalse() {
        XCTAssertFalse(sut.validateMegaFolderURL("https://googledrive.com/folder/nodeId#key"))
    }

    // MARK: - validateAPIKey() / validateFolderID()

    func test_validateAPIKey_shortKey_returnsFalse() {
        XCTAssertFalse(sut.validateAPIKey("short"))
    }

    func test_validateAPIKey_longEnoughKey_returnsTrue() {
        XCTAssertTrue(sut.validateAPIKey("AIzaSyBcDEFGHIJKLMNOPQRSTUVWXYZ1234567"))
    }

    func test_validateAPIKey_empty_returnsFalse() {
        XCTAssertFalse(sut.validateAPIKey(""))
    }

    func test_validateFolderID_shortID_returnsFalse() {
        XCTAssertFalse(sut.validateFolderID("short"))
    }

    func test_validateFolderID_validLength_returnsTrue() {
        XCTAssertTrue(sut.validateFolderID("1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE"))
    }

    func test_validateFolderID_empty_returnsFalse() {
        XCTAssertFalse(sut.validateFolderID(""))
    }

    // MARK: - Provider Selection

    func test_getSelectedCloudProvider_delegatesToRepository() {
        mockCredentials.selectedProvider = .mega
        XCTAssertEqual(sut.getSelectedCloudProvider(), .mega)

        mockCredentials.selectedProvider = .googleDrive
        XCTAssertEqual(sut.getSelectedCloudProvider(), .googleDrive)
    }

    func test_setSelectedProvider_updatesMock() {
        sut.setSelectedCloudProvider(.mega)

        XCTAssertEqual(mockCredentials.selectedProvider, .mega)
    }

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

    // MARK: - testCloudStorageConnection()

    func test_testCloudConnection_success_returnsTrue() async throws {
        mockCloudStorage.shouldThrowOnFetch = false

        let result = try await sut.testCloudStorageConnection()

        XCTAssertTrue(result)
    }

    func test_testCloudConnection_failure_throwsConnectionFailed() async {
        mockCloudStorage.shouldThrowOnFetch = true

        do {
            _ = try await sut.testCloudStorageConnection()
            XCTFail("Expected SettingsError.connectionFailed")
        } catch is SettingsError {
            // pass
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
