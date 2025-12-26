//
//  CredentialsManagementService.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import Foundation

// MARK: - Credentials Management Service (Single Responsibility)

/// Servicio responsable de gestionar las credenciales de Google Drive
final class CredentialsManagementService: CredentialsServiceProtocol {
    nonisolated(unsafe) private let keychainService: KeychainService

    nonisolated init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService
    }

    // MARK: - CredentialsServiceProtocol

    func loadCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        let apiKey = keychainService.googleDriveAPIKey ?? ""
        let folderId = keychainService.googleDriveFolderId ?? ""
        let hasCredentials = !apiKey.isEmpty && !folderId.isEmpty

        return (apiKey, folderId, hasCredentials)
    }

    func saveCredentials(apiKey: String, folderId: String) -> Bool {
        let apiKeySaved = keychainService.save(apiKey, for: .googleDriveAPIKey)
        let folderIdSaved = keychainService.save(folderId, for: .googleDriveFolderId)

        return apiKeySaved && folderIdSaved
    }

    func deleteCredentials() {
        keychainService.delete(for: .googleDriveAPIKey)
        keychainService.delete(for: .googleDriveFolderId)
    }

    var hasCredentials: Bool {
        keychainService.hasGoogleDriveCredentials
    }
}

// MARK: - Sendable Conformance

extension CredentialsManagementService: Sendable {}
