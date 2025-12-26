//
//  SettingsViewModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Refactored with Swift 6 improvements
//

import Foundation
import SwiftData

// MARK: - Settings ViewModel (Legacy Support + Swift 6 Improvements)

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var showDeleteAllAlert = false
    @Published var showSaveConfirmation = false
    @Published var showDeleteCredentialsAlert = false
    @Published var apiKey: String = ""
    @Published var folderId: String = ""
    @Published var hasExistingCredentials = false

    // MARK: - Dependencies (Dependency Injection)

    private let googleDriveService: GoogleDriveServiceProtocol
    private let keychainService: KeychainService

    // MARK: - Initialization

    init(
        googleDriveService: GoogleDriveServiceProtocol = GoogleDriveService(),
        keychainService: KeychainService = .shared
    ) {
        self.googleDriveService = googleDriveService
        self.keychainService = keychainService
    }

    // MARK: - Storage Management

    /// Calcula el almacenamiento total usado por canciones descargadas
    func calculateTotalStorageUsed(for songs: [Song]) -> String {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        for song in songs where song.isDownloaded {
            if let localURL = googleDriveService.localURL(for: song.id),
               fileManager.fileExists(atPath: localURL.path) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                } catch {
                    continue
                }
            }
        }

        return formatBytes(totalSize)
    }

    /// Filtra canciones pendientes (no descargadas)
    func filterPendingSongs(_ songs: [Song]) -> [Song] {
        songs.filter { !$0.isDownloaded }
    }

    /// Filtra canciones descargadas
    func filterDownloadedSongs(_ songs: [Song]) -> [Song] {
        songs.filter { $0.isDownloaded }
    }

    /// Elimina todas las descargas
    func deleteAllDownloads(songs: [Song], modelContext: ModelContext, playerViewModel: PlayerViewModel) async {
        // Pausar reproducción si hay algo tocando
        if playerViewModel.isPlaying {
            playerViewModel.pause()
        }

        let downloadedSongs = songs.filter { $0.isDownloaded }

        for song in downloadedSongs {
            // Eliminar el archivo descargado
            do {
                try googleDriveService.deleteDownload(for: song.id)
            } catch {
                print("Error al eliminar descarga de \(song.title): \(error)")
            }

            // Resetear los datos de la canción
            song.isDownloaded = false
            song.duration = nil
            song.artworkData = nil
            song.album = nil
            song.author = nil
        }

        // Guardar todos los cambios
        do {
            try modelContext.save()
            print("✅ Todas las descargas eliminadas exitosamente")
        } catch {
            print("❌ Error al guardar cambios: \(error)")
        }
    }

    // MARK: - Google Drive Credentials

    /// Carga las credenciales guardadas del Keychain
    func loadCredentials() {
        if let savedAPIKey = keychainService.googleDriveAPIKey {
            apiKey = savedAPIKey
            hasExistingCredentials = true
        } else {
            apiKey = ""
        }

        if let savedFolderId = keychainService.googleDriveFolderId {
            folderId = savedFolderId
        } else {
            folderId = ""
        }
    }

    /// Guarda las credenciales en el Keychain
    func saveCredentials(modelContext: ModelContext, libraryViewModel: LibraryViewModel) {
        let apiKeySaved = keychainService.save(apiKey, for: .googleDriveAPIKey)
        let folderIdSaved = keychainService.save(folderId, for: .googleDriveFolderId)

        if apiKeySaved && folderIdSaved {
            hasExistingCredentials = true
            showSaveConfirmation = true
            print("✅ Credenciales guardadas en Keychain")

            // Sincronizar automáticamente después de guardar credenciales
            libraryViewModel.syncLibraryWithCatalog(modelContext: modelContext)
        } else {
            print("❌ Error al guardar credenciales")
        }
    }

    /// Elimina las credenciales del Keychain y limpia la biblioteca
    func deleteCredentials(modelContext: ModelContext, libraryViewModel: LibraryViewModel) {
        keychainService.delete(for: .googleDriveAPIKey)
        keychainService.delete(for: .googleDriveFolderId)
        apiKey = ""
        folderId = ""
        hasExistingCredentials = false
        libraryViewModel.clearLibrary(modelContext: modelContext)
        print("🗑️ Credenciales eliminadas del Keychain y biblioteca local limpiada.")
    }

    /// Verifica si las credenciales son válidas (no vacías)
    var areCredentialsValid: Bool {
        !apiKey.isEmpty && !folderId.isEmpty
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
