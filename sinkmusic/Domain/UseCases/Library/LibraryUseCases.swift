//
//  LibraryUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para la biblioteca de música
/// Gestiona sincronización con almacenamiento cloud y acceso a canciones
@MainActor
final class LibraryUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol
    private let credentialsRepository: CredentialsRepositoryProtocol

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

    /// Obtiene canciones reproducidas recientemente
    /// - Parameter limit: Número máximo de canciones a retornar
    func getRecentlyPlayedSongs(limit: Int = 10) async throws -> [Song] {
        let allSongs = try await songRepository.getAll()
        return allSongs
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
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
        // Verificar credenciales
        guard credentialsRepository.hasGoogleDriveCredentials() else {
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

    /// Verifica si hay credenciales configuradas
    func hasCredentials() -> Bool {
        return credentialsRepository.hasGoogleDriveCredentials()
    }

    // MARK: - Song Management

    /// Elimina una canción de la biblioteca
    func deleteSong(_ id: UUID) async throws {
        // Eliminar archivo descargado si existe
        try? cloudStorageRepository.deleteDownload(for: id)

        // Eliminar de la base de datos
        try await songRepository.delete(id)
    }

    /// Elimina múltiples canciones
    func deleteSongs(_ ids: [UUID]) async throws {
        for id in ids {
            try await deleteSong(id)
        }
    }

    // MARK: - Statistics

    /// Obtiene estadísticas de la biblioteca
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
