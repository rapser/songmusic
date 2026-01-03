//
//  SettingsUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
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
    private let googleDriveRepository: GoogleDriveRepositoryProtocol

    // MARK: - Initialization

    init(
        credentialsRepository: CredentialsRepositoryProtocol,
        songRepository: SongRepositoryProtocol,
        googleDriveRepository: GoogleDriveRepositoryProtocol
    ) {
        self.credentialsRepository = credentialsRepository
        self.songRepository = songRepository
        self.googleDriveRepository = googleDriveRepository
    }

    // MARK: - Google Drive Credentials

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
            var updatedSong = song
            updatedSong = SongEntity(
                id: updatedSong.id,
                title: updatedSong.title,
                artist: updatedSong.artist,
                album: updatedSong.album,
                fileID: updatedSong.fileID,
                isDownloaded: updatedSong.isDownloaded,
                duration: updatedSong.duration,
                artworkData: nil,
                artworkThumbnail: nil,
                artworkMediumThumbnail: nil,
                playCount: updatedSong.playCount,
                lastPlayedAt: updatedSong.lastPlayedAt,
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
            try? googleDriveRepository.deleteDownload(for: song.id)
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

    /// Valida credenciales probando la conexión con Google Drive
    func testGoogleDriveConnection() async throws -> Bool {
        do {
            _ = try await googleDriveRepository.fetchSongsFromFolder()
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
