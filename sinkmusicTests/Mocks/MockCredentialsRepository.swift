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

    func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        (googleDriveAPIKey, googleDriveFolderID, hasGoogleDriveCredentialsValue)
    }

    func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool {
        guard saveGoogleDriveResult else { return false }
        googleDriveAPIKey = apiKey
        googleDriveFolderID = folderId
        hasGoogleDriveCredentialsValue = true
        return true
    }

    func deleteGoogleDriveCredentials() {
        googleDriveAPIKey = ""
        googleDriveFolderID = ""
        hasGoogleDriveCredentialsValue = false
    }

    func hasGoogleDriveCredentials() -> Bool { hasGoogleDriveCredentialsValue }

    func loadMegaFolderURL() -> String { megaFolderURL }

    func saveMegaFolderURL(_ url: String) -> Bool {
        guard saveMegaResult else { return false }
        megaFolderURL = url
        hasMegaCredentialsValue = true
        return true
    }

    func deleteMegaCredentials() {
        megaFolderURL = ""
        hasMegaCredentialsValue = false
    }

    func hasMegaCredentials() -> Bool { hasMegaCredentialsValue }

    func getSelectedCloudProvider() -> CloudStorageProvider { selectedProvider }

    func setSelectedCloudProvider(_ provider: CloudStorageProvider) {
        selectedProvider = provider
    }
}
