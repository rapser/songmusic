//
//  CredentialsRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Credenciales
/// Encapsula el KeychainService y proporciona acceso a credenciales seguras
@MainActor
final class CredentialsRepositoryImpl: CredentialsRepositoryProtocol {

    // MARK: - Dependencies

    private let keychainService: KeychainServiceProtocol

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

    // MARK: - Google Drive

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

    // MARK: - Mega

    func loadMegaFolderURL() -> String {
        return keychainService.megaFolderURL ?? ""
    }

    func saveMegaFolderURL(_ url: String) -> Bool {
        return keychainService.save(url, for: .megaFolderURL)
    }

    func deleteMegaCredentials() {
        keychainService.delete(for: .megaFolderURL)
    }

    func hasMegaCredentials() -> Bool {
        return keychainService.hasMegaCredentials
    }

    // MARK: - Provider Selection

    func getSelectedCloudProvider() -> CloudStorageProvider {
        guard let providerString = keychainService.selectedCloudProvider,
              let provider = CloudStorageProvider(rawValue: providerString) else {
            // Default a Google Drive si no hay selección
            return .googleDrive
        }
        return provider
    }

    func setSelectedCloudProvider(_ provider: CloudStorageProvider) {
        _ = keychainService.save(provider.rawValue, for: .selectedCloudProvider)
    }
}

// MARK: - Sendable Conformance

extension CredentialsRepositoryImpl: Sendable {}
