//
//  CredentialsRepositoryImpl.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Credenciales
/// Encapsula el KeychainService y proporciona acceso a credenciales seguras
@MainActor
final class CredentialsRepositoryImpl: CredentialsRepositoryProtocol {

    // MARK: - Dependencies

    private let keychainService: KeychainService

    // MARK: - Initialization

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    // MARK: - CredentialsRepositoryProtocol

    func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        let apiKey = keychainService.googleDriveAPIKey ?? ""
        let folderId = keychainService.googleDriveFolderId ?? ""
        let hasCredentials = keychainService.hasGoogleDriveCredentials

        return (apiKey: apiKey, folderId: folderId, hasCredentials: hasCredentials)
    }

    func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool {
        let apiKeySuccess = keychainService.save(apiKey, for: .googleDriveAPIKey)
        let folderIdSuccess = keychainService.save(folderId, for: .googleDriveFolderId)

        return apiKeySuccess && folderIdSuccess
    }

    func deleteGoogleDriveCredentials() {
        keychainService.delete(for: .googleDriveAPIKey)
        keychainService.delete(for: .googleDriveFolderId)
    }

    func hasGoogleDriveCredentials() -> Bool {
        return keychainService.hasGoogleDriveCredentials
    }
}

// MARK: - Sendable Conformance

extension CredentialsRepositoryImpl: Sendable {}
