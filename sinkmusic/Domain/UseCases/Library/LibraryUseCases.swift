//
//  LibraryUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation
import os

/// Casos de uso agrupados para la biblioteca de música
/// Gestiona sincronización con almacenamiento cloud y acceso a canciones
@MainActor
final class LibraryUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol
    private let credentialsRepository: CredentialsRepositoryProtocol
    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Library")

    // MARK: - Initialization

    init(
        songRepository: SongRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol,
        credentialsRepository: CredentialsRepositoryProtocol
    ) {
        self.songRepository = songRepository
        self.cloudStorageRepository = cloudStorageRepository
        self.credentialsRepository = credentialsRepository
    }

    // MARK: - Library Access

    /// Obtiene todas las canciones de la biblioteca local
    func getAllSongs() async throws -> [Song] {
        return try await songRepository.getAll()
    }

    /// Obtiene una canción por ID
    func getSongByID(_ id: UUID) async throws -> Song? {
        return try await songRepository.getByID(id)
    }

    /// Obtiene canciones reproducidas recientemente (query targeted, no getAll()+filter)
    /// - Parameter limit: Número máximo de canciones a retornar
    func getRecentlyPlayedSongs(limit: Int = 10) async throws -> [Song] {
        return try await songRepository.getRecentlyPlayed(limit: limit)
    }

    /// Obtiene las canciones más reproducidas
    /// - Parameter limit: Número máximo de canciones a retornar
    func getMostPlayedSongs(limit: Int = 10) async throws -> [Song] {
        return try await songRepository.getTopSongs(limit: limit)
    }

    /// Obtiene canciones descargadas
    func getDownloadedSongs() async throws -> [Song] {
        return try await songRepository.getDownloaded()
    }

    // MARK: - Sync with Cloud Storage

    /// Sincroniza la biblioteca con almacenamiento cloud
    /// Retorna el número de canciones nuevas agregadas
    func syncWithCloudStorage() async throws -> Int {
        // Verificar credenciales según proveedor seleccionado
        let provider = credentialsRepository.getSelectedCloudProvider()

        let providerHasCredentials: Bool
        switch provider {
        case .googleDrive:
            providerHasCredentials = credentialsRepository.hasGoogleDriveCredentials()
        case .mega:
            providerHasCredentials = credentialsRepository.hasMegaCredentials()
        }

        guard providerHasCredentials else {
            throw LibraryError.credentialsNotConfigured
        }

        // Obtener archivos remotos (CloudFile - entidad de dominio)
        let remoteFiles = try await cloudStorageRepository.fetchSongsFromFolder()

        // Obtener canciones locales
        let localSongs = try await songRepository.getAll()
        let localFileIDs = Set(localSongs.map { $0.fileID })

        // Filtrar nuevas canciones
        let newFiles = remoteFiles.filter { !localFileIDs.contains($0.id) }

        // Crear entidades para nuevas canciones
        var newSongsCount = 0
        for file in newFiles {
            let newSong = Song(
                id: UUID(),
                title: file.title,
                artist: file.artist,
                album: nil,
                author: nil,
                fileID: file.id,
                isDownloaded: false,
                duration: nil,
                artworkData: nil,
                artworkThumbnail: nil,
                artworkMediumThumbnail: nil,
                playCount: 0,
                lastPlayedAt: nil,
                dominantColor: nil
            )

            try await songRepository.create(newSong)
            newSongsCount += 1
        }

        return newSongsCount
    }

    /// Verifica si hay credenciales configuradas para el proveedor seleccionado
    func hasCredentials() -> Bool {
        let provider = credentialsRepository.getSelectedCloudProvider()
        switch provider {
        case .googleDrive:
            return credentialsRepository.hasGoogleDriveCredentials()
        case .mega:
            return credentialsRepository.hasMegaCredentials()
        }
    }

    // MARK: - Song Management

    /// Guarda el color dominante calculado del artwork para una canción (primera vez que se muestra).
    /// En siguientes cargas se usará el valor guardado.
    func updateDominantColor(songID: UUID, red: Double, green: Double, blue: Double) async throws {
        guard let existing = try await songRepository.getByID(songID) else { return }
        let color = RGBColor(red: red, green: green, blue: blue)
        let updated = Song(
            id: existing.id,
            title: existing.title,
            artist: existing.artist,
            album: existing.album,
            author: existing.author,
            fileID: existing.fileID,
            isDownloaded: existing.isDownloaded,
            duration: existing.duration,
            artworkData: existing.artworkData,
            artworkThumbnail: existing.artworkThumbnail,
            artworkMediumThumbnail: existing.artworkMediumThumbnail,
            playCount: existing.playCount,
            lastPlayedAt: existing.lastPlayedAt,
            dominantColor: color
        )
        try await songRepository.update(updated)
    }

    /// Elimina una canción de la biblioteca
    func deleteSong(_ id: UUID) async throws {
        // Eliminar archivo descargado si existe
        try? cloudStorageRepository.deleteDownload(for: id)

        // Eliminar de la base de datos
        try await songRepository.delete(id)
    }

    /// Elimina múltiples canciones en modo best-effort.
    /// Si una falla, continúa con las demás y reporta todos los fallos en el `BatchResult`.
    func deleteSongs(_ ids: [UUID]) async -> BatchResult<UUID> {
        var succeeded: [UUID] = []
        var failed: [(id: UUID, error: Error)] = []

        for id in ids {
            do {
                try await deleteSong(id)
                succeeded.append(id)
            } catch {
                logger.error("Error al eliminar canción \(id): \(error)")
                failed.append((id: id, error: error))
            }
        }
        return BatchResult(succeeded: succeeded, failed: failed)
    }

    // MARK: - Statistics

    /// Obtiene estadísticas de la biblioteca.
    /// Excepción aceptada: usa `getAll()` porque son agregaciones (conteos/sumas) sobre
    /// *todas* las canciones — SwiftData no soporta agregación a nivel de `FetchDescriptor`.
    func getLibraryStats() async throws -> LibraryStats {
        let songs = try await songRepository.getAll()

        let totalSongs = songs.count
        let downloadedSongs = songs.filter { $0.isDownloaded }.count
        let totalDuration = songs.compactMap { $0.duration }.reduce(0, +)
        let totalPlays = songs.map { $0.playCount }.reduce(0, +)
        let uniqueArtists = Set(songs.map { $0.artist }).count
        let uniqueAlbums = Set(songs.compactMap { $0.album }).count

        return LibraryStats(
            totalSongs: totalSongs,
            downloadedSongs: downloadedSongs,
            totalDuration: totalDuration,
            totalPlays: totalPlays,
            uniqueArtists: uniqueArtists,
            uniqueAlbums: uniqueAlbums
        )
    }
}

// MARK: - Library Stats

struct LibraryStats: Sendable {
    let totalSongs: Int
    let downloadedSongs: Int
    let totalDuration: TimeInterval
    let totalPlays: Int
    let uniqueArtists: Int
    let uniqueAlbums: Int

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Errors

enum LibraryError: Error {
    case credentialsNotConfigured
    case syncFailed
    case deleteFailed
}

// MARK: - Sendable Conformance

extension LibraryUseCases: Sendable {}
