//
//  RefactoredSettingsViewModel.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import Foundation
import SwiftData
import Observation

// MARK: - Refactored Settings ViewModel (Swift 6 + SOLID + MVVM)

/// ViewModel para la pantalla de configuración
/// Sigue principios SOLID:
/// - Single Responsibility: Solo gestiona el estado de la UI de configuración
/// - Open/Closed: Extensible mediante inyección de dependencias
/// - Liskov Substitution: Usa protocolos para servicios
/// - Interface Segregation: Protocolos específicos para cada servicio
/// - Dependency Inversion: Depende de abstracciones, no de implementaciones concretas
@MainActor
@Observable
final class RefactoredSettingsViewModel {
    // MARK: - Published State (Swift 6 @Observable)

    private(set) var state: SettingsState = SettingsState()
    var showDeleteAllAlert = false
    var showSignOutAlert = false

    // Google Drive credentials state
    var apiKey: String = ""
    var folderId: String = ""
    var showSaveConfirmation = false
    var showDeleteCredentialsAlert = false

    // MARK: - Dependencies (Dependency Injection)

    private let storageService: SettingsServiceProtocol
    private let credentialsService: CredentialsServiceProtocol

    // MARK: - Initialization

    init(
        storageService: SettingsServiceProtocol = StorageManagementService(),
        credentialsService: CredentialsServiceProtocol = CredentialsManagementService()
    ) {
        self.storageService = storageService
        self.credentialsService = credentialsService
        loadInitialState()
    }

    // MARK: - Public Methods

    /// Actualiza el estado con los datos de las canciones
    func updateState(with songs: [Song]) {
        let pendingSongs = storageService.filterPendingSongs(songs)
        let downloadedSongs = storageService.filterDownloadedSongs(songs)
        let storageUsed = storageService.calculateStorageUsed(for: songs)

        state.pendingSongsCount = pendingSongs.count
        state.downloadedSongsCount = downloadedSongs.count
        state.totalStorageUsed = storageUsed
        state.isGoogleDriveConfigured = credentialsService.hasCredentials
    }

    /// Actualiza el perfil del usuario
    func updateUserProfile(fullName: String?, email: String?, userID: String?) {
        state.userProfile = UserProfileData(
            fullName: fullName,
            email: email,
            userID: userID,
            isAppleAccount: true
        )
    }

    /// Elimina todas las descargas
    func deleteAllDownloads(
        songs: [Song],
        modelContext: ModelContext,
        onCompletion: @escaping () -> Void
    ) async {
        do {
            try await storageService.deleteAllDownloads(
                songs: songs,
                modelContext: modelContext
            )

            // Actualizar el estado después de eliminar
            updateState(with: songs)

            // Callback para pausar el reproductor si es necesario
            onCompletion()

            print("✅ Todas las descargas eliminadas exitosamente")
        } catch {
            print("❌ Error al eliminar descargas: \(error)")
        }
    }

    // MARK: - Google Drive Credentials

    /// Carga las credenciales guardadas
    func loadCredentials() {
        let credentials = credentialsService.loadCredentials()
        apiKey = credentials.apiKey
        folderId = credentials.folderId
        state.isGoogleDriveConfigured = credentials.hasCredentials
    }

    /// Guarda las credenciales
    func saveCredentials(onSuccess: @escaping () -> Void) {
        let success = credentialsService.saveCredentials(
            apiKey: apiKey,
            folderId: folderId
        )

        if success {
            state.isGoogleDriveConfigured = true
            showSaveConfirmation = true
            onSuccess()
            print("✅ Credenciales guardadas en Keychain")
        } else {
            print("❌ Error al guardar credenciales")
        }
    }

    /// Elimina las credenciales
    func deleteCredentials(onSuccess: @escaping () -> Void) {
        credentialsService.deleteCredentials()
        apiKey = ""
        folderId = ""
        state.isGoogleDriveConfigured = false
        onSuccess()
        print("🗑️ Credenciales eliminadas del Keychain")
    }

    /// Valida si las credenciales son válidas
    var areCredentialsValid: Bool {
        !apiKey.isEmpty && !folderId.isEmpty
    }

    // MARK: - Private Methods

    private func loadInitialState() {
        loadCredentials()
    }

    // MARK: - Computed Properties for UI

    var hasDownloadedSongs: Bool {
        state.downloadedSongsCount > 0
    }

    var hasPendingSongs: Bool {
        state.pendingSongsCount > 0
    }
}

// MARK: - Sendable Conformance

extension RefactoredSettingsViewModel: Sendable {}
