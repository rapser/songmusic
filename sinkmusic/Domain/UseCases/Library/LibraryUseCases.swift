//
//  LibraryUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para la biblioteca de música
/// Gestiona sincronización con Google Drive y acceso a canciones
@MainActor
final class LibraryUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol
    private let googleDriveRepository: GoogleDriveRepositoryProtocol
    private let credentialsRepository: CredentialsRepositoryProtocol

    // MARK: - Initialization

    init(
        songRepository: SongRepositoryProtocol,
        googleDriveRepository: GoogleDriveRepositoryProtocol,
        credentialsRepository: CredentialsRepositoryProtocol
    ) {
        self.songRepository = songRepository
        self.googleDriveRepository = googleDriveRepository
        self.credentialsRepository = credentialsRepository
    }

    // MARK: - Library Access

    /// Obtiene todas las canciones de la biblioteca local
    func getAllSongs() async throws -> [SongEntity] {
        return try await songRepository.getAll()
    }

    /// Obtiene una canción por ID
    func getSongByID(_ id: UUID) async throws -> SongEntity? {
        return try await songRepository.getByID(id)
    }

    /// Observa cambios en la biblioteca
    func observeLibraryChanges(onChange: @escaping @MainActor ([SongEntity]) -> Void) {
        songRepository.observeChanges(onChange: onChange)
    }

    // MARK: - Sync with Google Drive

    /// Sincroniza la biblioteca con Google Drive
    /// Retorna el número de canciones nuevas agregadas
    func syncWithGoogleDrive() async throws -> Int {
        // Verificar credenciales
        guard credentialsRepository.hasGoogleDriveCredentials() else {
            throw LibraryError.credentialsNotConfigured
        }

        // Obtener archivos remotos
        let remoteFiles = try await googleDriveRepository.fetchSongsFromFolder()

        // Obtener canciones locales
        let localSongs = try await songRepository.getAll()
        let localFileIDs = Set(localSongs.map { $0.fileID })

        // Filtrar nuevas canciones
        let newFiles = remoteFiles.filter { !localFileIDs.contains($0.id) }

        // Crear entidades para nuevas canciones
        var newSongsCount = 0
        for file in newFiles {
            let newSong = SongEntity(
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
        try? googleDriveRepository.deleteDownload(for: id)

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
