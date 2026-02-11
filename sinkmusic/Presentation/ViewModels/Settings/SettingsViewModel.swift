//
//  SettingsViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI de configuración
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de configuración
/// Delega lógica de negocio a SettingsUseCases y DownloadUseCases
@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Published State

    // Google Drive
    var apiKey: String = ""
    var folderId: String = ""
    var hasCredentials: Bool = false
    var hasExistingCredentials: Bool { hasCredentials }

    // Mega
    var megaFolderURL: String = ""
    var hasMegaCredentials: Bool = false

    // Provider selection
    var selectedProvider: CloudStorageProvider = .googleDrive

    var storageInfo: StorageInfo?
    var appInfo: AppInfo?
    var downloadStats: DownloadStats?

    var isTestingConnection: Bool = false
    var connectionTestResult: ConnectionTestResult?

    var showDeleteConfirmation: Bool = false
    var showClearCacheConfirmation: Bool = false
    var showSaveConfirmation: Bool = false
    var showDeleteCredentialsAlert: Bool = false
    var showQRScanner: Bool = false

    // MARK: - Dependencies

    private let settingsUseCases: SettingsUseCases
    private let downloadUseCases: DownloadUseCases

    // MARK: - Initialization

    init(
        settingsUseCases: SettingsUseCases,
        downloadUseCases: DownloadUseCases
    ) {
        self.settingsUseCases = settingsUseCases
        self.downloadUseCases = downloadUseCases
        loadCredentials()
        Task {
            await loadAllInfo()
        }
    }

    // MARK: - Credentials Management

    /// Carga todas las credenciales
    func loadCredentials() {
        // Google Drive
        let credentials = settingsUseCases.loadGoogleDriveCredentials()
        apiKey = credentials.apiKey
        folderId = credentials.folderId
        hasCredentials = credentials.hasCredentials

        // Mega
        megaFolderURL = settingsUseCases.loadMegaFolderURL()
        hasMegaCredentials = settingsUseCases.hasMegaCredentials()

        // Provider selection
        selectedProvider = settingsUseCases.getSelectedCloudProvider()
    }

    /// Guarda las credenciales
    func saveCredentials() -> Bool {
        let success = settingsUseCases.saveGoogleDriveCredentials(
            apiKey: apiKey,
            folderId: folderId
        )

        if success {
            hasCredentials = true
            print("✅ Credenciales guardadas correctamente")
        } else {
            print("❌ Error al guardar credenciales")
        }

        return success
    }

    /// Elimina las credenciales
    func deleteCredentials() {
        settingsUseCases.deleteGoogleDriveCredentials()
        apiKey = ""
        folderId = ""
        hasCredentials = false
        print("🗑️ Credenciales eliminadas")
    }

    /// Prueba la conexión con el almacenamiento cloud
    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        do {
            let isValid = try await settingsUseCases.testCloudStorageConnection()
            connectionTestResult = isValid ? .success : .failure("Credenciales inválidas")
            print("✅ Conexión exitosa con almacenamiento cloud")
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
            print("❌ Error al probar conexión: \(error)")
        }

        isTestingConnection = false
    }

    // MARK: - Data Management

    /// Carga información de almacenamiento
    func loadStorageInfo() async {
        do {
            storageInfo = try await settingsUseCases.getStorageInfo()
        } catch {
            print("❌ Error al cargar info de almacenamiento: \(error)")
        }
    }

    /// Carga estadísticas de descargas
    func loadDownloadStats() async {
        do {
            downloadStats = try await downloadUseCases.getDownloadStats()
        } catch {
            print("❌ Error al cargar estadísticas de descarga: \(error)")
        }
    }

    /// Carga información de la app
    func loadAppInfo() {
        appInfo = settingsUseCases.getAppInfo()
    }

    /// Carga toda la información
    func loadAllInfo() async {
        loadAppInfo()
        await loadStorageInfo()
        await loadDownloadStats()
    }

    /// Limpia la caché
    func clearCache() async {
        do {
            try await settingsUseCases.clearCache()
            await loadAllInfo()
            print("🧹 Caché limpiada correctamente")
        } catch {
            print("❌ Error al limpiar caché: \(error)")
        }
    }

    /// Elimina todas las canciones
    func deleteAllSongs() async {
        do {
            try await settingsUseCases.deleteAllSongs()
            await loadAllInfo()
            print("🗑️ Todas las canciones eliminadas")
        } catch {
            print("❌ Error al eliminar canciones: \(error)")
        }
    }

    /// Elimina todas las descargas (mantiene metadata)
    func deleteAllDownloads() async {
        do {
            try await downloadUseCases.deleteAllDownloads()
            await loadAllInfo()
            print("🗑️ Todas las descargas eliminadas")
        } catch {
            print("❌ Error al eliminar descargas: \(error)")
        }
    }

    // MARK: - Validation

    /// Valida la API Key
    func validateAPIKey() -> Bool {
        return settingsUseCases.validateAPIKey(apiKey)
    }

    /// Valida el Folder ID
    func validateFolderID() -> Bool {
        return settingsUseCases.validateFolderID(folderId)
    }

    /// Valida ambas credenciales
    func validateCredentials() -> Bool {
        return validateAPIKey() && validateFolderID()
    }

    /// Alias para validateCredentials (compatibilidad con GoogleDriveConfigView)
    var areCredentialsValid: Bool {
        validateCredentials()
    }

    /// Guarda credenciales (versión async para compatibilidad)
    func saveCredentialsAsync() async -> Bool {
        let success = saveCredentials()
        if success {
            showSaveConfirmation = true
        }
        return success
    }

    /// Elimina credenciales (versión async para compatibilidad)
    func deleteCredentialsAsync() async {
        deleteCredentials()
    }

    // MARK: - Mega Credentials

    /// Guarda la URL de la carpeta de Mega
    func saveMegaFolderURL() -> Bool {
        let success = settingsUseCases.saveMegaFolderURL(megaFolderURL)

        if success {
            hasMegaCredentials = true
            print("✅ URL de Mega guardada correctamente")
        } else {
            print("❌ Error al guardar URL de Mega")
        }

        return success
    }

    /// Elimina las credenciales de Mega
    func deleteMegaCredentials() {
        settingsUseCases.deleteMegaCredentials()
        megaFolderURL = ""
        hasMegaCredentials = false
        print("🗑️ Credenciales de Mega eliminadas")
    }

    /// Valida la URL de Mega
    func validateMegaFolderURL() -> Bool {
        return settingsUseCases.validateMegaFolderURL(megaFolderURL)
    }

    // MARK: - Provider Selection

    /// Cambia el proveedor de almacenamiento
    func setSelectedProvider(_ provider: CloudStorageProvider) {
        selectedProvider = provider
        settingsUseCases.setSelectedCloudProvider(provider)
        print("📦 Proveedor seleccionado: \(provider.rawValue)")
    }

    /// Verifica si el proveedor actual tiene credenciales configuradas
    var hasCurrentProviderCredentials: Bool {
        switch selectedProvider {
        case .googleDrive:
            return hasCredentials
        case .mega:
            return hasMegaCredentials
        }
    }
}

// MARK: - Connection Test Result

enum ConnectionTestResult {
    case success
    case failure(String)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}
