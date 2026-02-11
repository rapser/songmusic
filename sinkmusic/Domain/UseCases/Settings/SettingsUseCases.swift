//
//  SettingsUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para configuración de la app
/// Gestiona credenciales, sincronización y configuraciones generales
@MainActor
final class SettingsUseCases {

    // MARK: - Dependencies

    private let credentialsRepository: CredentialsRepositoryProtocol
    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol

    // MARK: - Initialization

    init(
        credentialsRepository: CredentialsRepositoryProtocol,
        songRepository: SongRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol
    ) {
        self.credentialsRepository = credentialsRepository
        self.songRepository = songRepository
        self.cloudStorageRepository = cloudStorageRepository
    }

    // MARK: - Cloud Storage Credentials

    /// Carga las credenciales de Google Drive
    func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        return credentialsRepository.loadGoogleDriveCredentials()
    }

    /// Guarda las credenciales de Google Drive
    func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool {
        // Validar que no estén vacíos
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty,
              !folderId.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        return credentialsRepository.saveGoogleDriveCredentials(
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            folderId: folderId.trimmingCharacters(in: .whitespaces)
        )
    }

    /// Elimina las credenciales de Google Drive
    func deleteGoogleDriveCredentials() {
        credentialsRepository.deleteGoogleDriveCredentials()
    }

    /// Verifica si hay credenciales configuradas
    func hasGoogleDriveCredentials() -> Bool {
        return credentialsRepository.hasGoogleDriveCredentials()
    }

    // MARK: - Mega Credentials

    /// Carga la URL de la carpeta de Mega
    func loadMegaFolderURL() -> String {
        return credentialsRepository.loadMegaFolderURL()
    }

    /// Guarda la URL de la carpeta de Mega
    func saveMegaFolderURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, validateMegaFolderURL(trimmed) else {
            return false
        }
        return credentialsRepository.saveMegaFolderURL(trimmed)
    }

    /// Elimina las credenciales de Mega
    func deleteMegaCredentials() {
        credentialsRepository.deleteMegaCredentials()
    }

    /// Verifica si hay credenciales de Mega configuradas
    func hasMegaCredentials() -> Bool {
        return credentialsRepository.hasMegaCredentials()
    }

    /// Valida el formato de la URL de carpeta de Mega
    func validateMegaFolderURL(_ url: String) -> Bool {
        // Formato: https://mega.nz/folder/{nodeId}#{key}
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("https://mega.nz/folder/") && trimmed.contains("#")
    }

    // MARK: - Provider Selection

    /// Obtiene el proveedor de almacenamiento seleccionado
    func getSelectedCloudProvider() -> CloudStorageProvider {
        return credentialsRepository.getSelectedCloudProvider()
    }

    /// Establece el proveedor de almacenamiento seleccionado
    func setSelectedCloudProvider(_ provider: CloudStorageProvider) {
        credentialsRepository.setSelectedCloudProvider(provider)
    }

    /// Verifica si hay credenciales del proveedor actual configuradas
    func hasCurrentProviderCredentials() -> Bool {
        switch getSelectedCloudProvider() {
        case .googleDrive:
            return hasGoogleDriveCredentials()
        case .mega:
            return hasMegaCredentials()
        }
    }

    // MARK: - Data Management

    /// Obtiene el tamaño estimado de los datos de la app
    func getStorageInfo() async throws -> StorageInfo {
        let songs = try await songRepository.getAll()
        let downloadedSongs = songs.filter { $0.isDownloaded }

        // Estimar tamaño (5MB por canción descargada)
        let estimatedSize = Double(downloadedSongs.count) * 5.0

        // Calcular tamaño de artwork cacheado
        let artworkSize = songs.compactMap { $0.artworkData?.count ?? 0 }.reduce(0, +)
        let artworkSizeMB = Double(artworkSize) / (1024 * 1024)

        return StorageInfo(
            totalSongs: songs.count,
            downloadedSongs: downloadedSongs.count,
            estimatedAudioSizeMB: estimatedSize,
            artworkSizeMB: artworkSizeMB,
            totalSizeMB: estimatedSize + artworkSizeMB
        )
    }

    /// Limpia toda la caché de la app
    func clearCache() async throws {
        // Obtener todas las canciones
        let songs = try await songRepository.getAll()

        // Limpiar artwork de canciones no descargadas
        for song in songs where !song.isDownloaded {
            let updatedSong = Song(
                id: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                author: song.author,
                fileID: song.fileID,
                isDownloaded: song.isDownloaded,
                duration: song.duration,
                artworkData: nil,
                artworkThumbnail: nil,
                artworkMediumThumbnail: nil,
                playCount: song.playCount,
                lastPlayedAt: song.lastPlayedAt,
                dominantColor: nil
            )
            try await songRepository.update(updatedSong)
        }
    }

    /// Elimina todas las canciones de la biblioteca
    func deleteAllSongs() async throws {
        let songs = try await songRepository.getAll()

        // Eliminar archivos descargados
        for song in songs where song.isDownloaded {
            try? cloudStorageRepository.deleteDownload(for: song.id)
        }

        // Eliminar todas las canciones de la base de datos
        for song in songs {
            try await songRepository.delete(song.id)
        }
    }

    // MARK: - App Info

    /// Obtiene información de la app
    func getAppInfo() -> AppInfo {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return AppInfo(
            version: appVersion,
            build: buildNumber,
            displayName: "SinkMusic"
        )
    }

    // MARK: - Validation

    /// Valida el formato de una API Key de Google Drive
    func validateAPIKey(_ apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        // API Keys de Google suelen tener 39 caracteres alfanuméricos
        return trimmed.count >= 30 && !trimmed.isEmpty
    }

    /// Valida el formato de un Folder ID de Google Drive
    func validateFolderID(_ folderId: String) -> Bool {
        let trimmed = folderId.trimmingCharacters(in: .whitespaces)
        // Folder IDs suelen tener entre 25-50 caracteres alfanuméricos
        return trimmed.count >= 20 && !trimmed.isEmpty
    }

    /// Valida credenciales probando la conexión con el almacenamiento cloud
    func testCloudStorageConnection() async throws -> Bool {
        do {
            _ = try await cloudStorageRepository.fetchSongsFromFolder()
            return true
        } catch {
            throw SettingsError.connectionFailed(error)
        }
    }
}

// MARK: - Storage Info

struct StorageInfo: Sendable {
    let totalSongs: Int
    let downloadedSongs: Int
    let estimatedAudioSizeMB: Double
    let artworkSizeMB: Double
    let totalSizeMB: Double

    var formattedTotalSize: String {
        if totalSizeMB > 1024 {
            return String(format: "%.2f GB", totalSizeMB / 1024)
        } else {
            return String(format: "%.0f MB", totalSizeMB)
        }
    }

    var formattedAudioSize: String {
        if estimatedAudioSizeMB > 1024 {
            return String(format: "%.2f GB", estimatedAudioSizeMB / 1024)
        } else {
            return String(format: "%.0f MB", estimatedAudioSizeMB)
        }
    }

    var formattedArtworkSize: String {
        return String(format: "%.1f MB", artworkSizeMB)
    }
}

// MARK: - App Info

struct AppInfo: Sendable {
    let version: String
    let build: String
    let displayName: String

    var fullVersion: String {
        return "\(version) (\(build))"
    }
}

// MARK: - Errors

enum SettingsError: Error {
    case invalidCredentials
    case connectionFailed(Error)
    case saveFailed
}

// MARK: - Sendable Conformance

extension SettingsUseCases: Sendable {}
