//
//  MockCredentialsRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockCredentialsRepository: CredentialsRepositoryProtocol {

    var googleDriveAPIKey = ""
    var googleDriveFolderID = ""
    var megaFolderURL = ""
    var selectedProvider: CloudStorageProvider = .googleDrive

    var hasGoogleDriveCredentialsValue = false
    var hasMegaCredentialsValue = false
    var saveGoogleDriveResult = true
    var saveMegaResult = true

    // MARK: - Call tracking
    var saveGoogleDriveCallCount = 0
    var deleteGoogleDriveCallCount = 0
    var saveMegaCallCount = 0
    var deleteMegaCallCount = 0
    var setProviderCallCount = 0
    var getProviderCallCount = 0

    func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        (googleDriveAPIKey, googleDriveFolderID, hasGoogleDriveCredentialsValue)
    }

    func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool {
        saveGoogleDriveCallCount += 1
        guard saveGoogleDriveResult else { return false }
        googleDriveAPIKey = apiKey
        googleDriveFolderID = folderId
        hasGoogleDriveCredentialsValue = true
        return true
    }

    func deleteGoogleDriveCredentials() {
        deleteGoogleDriveCallCount += 1
        googleDriveAPIKey = ""
        googleDriveFolderID = ""
        hasGoogleDriveCredentialsValue = false
    }

    func hasGoogleDriveCredentials() -> Bool { hasGoogleDriveCredentialsValue }

    func loadMegaFolderURL() -> String { megaFolderURL }

    func saveMegaFolderURL(_ url: String) -> Bool {
        saveMegaCallCount += 1
        guard saveMegaResult else { return false }
        megaFolderURL = url
        hasMegaCredentialsValue = true
        return true
    }

    func deleteMegaCredentials() {
        deleteMegaCallCount += 1
        megaFolderURL = ""
        hasMegaCredentialsValue = false
    }

    func hasMegaCredentials() -> Bool { hasMegaCredentialsValue }

    func getSelectedCloudProvider() -> CloudStorageProvider {
        getProviderCallCount += 1
        return selectedProvider
    }

    func setSelectedCloudProvider(_ provider: CloudStorageProvider) {
        setProviderCallCount += 1
        selectedProvider = provider
    }
}
