//
//  DownloadUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para descarga de canciones
/// Gestiona descarga, extracción de metadata y almacenamiento
@MainActor
final class DownloadUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    // MARK: - Initialization

    init(
        songRepository: SongRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.songRepository = songRepository
        self.cloudStorageRepository = cloudStorageRepository
        self.metadataRepository = metadataRepository
    }

    // MARK: - Download Operations

    /// Descarga una canción desde el almacenamiento cloud
    /// El progreso se emite via EventBus como DownloadEvent.progress
    func downloadSong(_ songID: UUID) async throws {
        // Obtener la canción
        guard var song = try await songRepository.getByID(songID) else {
            throw DownloadError.songNotFound
        }

        // Verificar que no esté ya descargada
        if song.isDownloaded {
            throw DownloadError.alreadyDownloaded
        }

        // Descargar archivo (el progreso se emite via EventBus desde el DataSource)
        let localURL = try await cloudStorageRepository.download(
            fileID: song.fileID,
            songID: songID
        )

        // Extraer metadata
        if let metadata = await metadataRepository.extractMetadata(from: localURL) {
            // Actualizar canción con metadata
            song = SongEntity(
                id: song.id,
                title: metadata.title.isEmpty ? song.title : metadata.title,
                artist: metadata.artist.isEmpty ? song.artist : metadata.artist,
                album: metadata.album.isEmpty ? song.album : metadata.album,
                author: song.author,
                fileID: song.fileID,
                isDownloaded: true,
                duration: metadata.duration,
                artworkData: metadata.artwork,
                artworkThumbnail: metadata.artworkThumbnail,
                artworkMediumThumbnail: metadata.artworkMediumThumbnail,
                playCount: song.playCount,
                lastPlayedAt: song.lastPlayedAt,
                dominantColor: song.dominantColor
            )
        } else {
            // Metadata extraction falló, solo marcar como descargada
            let duration = cloudStorageRepository.getDuration(for: localURL)
            song = SongEntity(
                id: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                author: song.author,
                fileID: song.fileID,
                isDownloaded: true,
                duration: duration,
                artworkData: song.artworkData,
                artworkThumbnail: song.artworkThumbnail,
                artworkMediumThumbnail: song.artworkMediumThumbnail,
                playCount: song.playCount,
                lastPlayedAt: song.lastPlayedAt,
                dominantColor: song.dominantColor
            )
        }

        // Actualizar en la base de datos
        try await songRepository.update(song)
    }

    /// Descarga múltiples canciones
    /// El progreso y completado de cada canción se emite via EventBus
    func downloadMultipleSongs(_ songIDs: [UUID]) async {
        for songID in songIDs {
            do {
                try await downloadSong(songID)
            } catch {
                print("⚠️ Error al descargar canción \(songID): \(error)")
            }
        }
    }

    /// Elimina una descarga
    func deleteDownload(_ songID: UUID) async throws {
        // Obtener la canción
        guard var song = try await songRepository.getByID(songID) else {
            throw DownloadError.songNotFound
        }

        // Verificar que esté descargada
        guard song.isDownloaded else {
            throw DownloadError.notDownloaded
        }

        // Eliminar archivo local
        try cloudStorageRepository.deleteDownload(for: songID)

        // Actualizar canción (marcar como no descargada, limpiar metadata local)
        song = SongEntity(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            author: song.author,
            fileID: song.fileID,
            isDownloaded: false,
            duration: song.duration,
            artworkData: nil,
            artworkThumbnail: nil,
            artworkMediumThumbnail: nil,
            playCount: song.playCount,
            lastPlayedAt: song.lastPlayedAt,
            dominantColor: nil
        )

        try await songRepository.update(song)
    }

    /// Elimina todas las descargas
    func deleteAllDownloads() async throws {
        let songs = try await songRepository.getAll()
        let downloadedSongs = songs.filter { $0.isDownloaded }

        for song in downloadedSongs {
            try await deleteDownload(song.id)
        }
    }

    // MARK: - Download Info

    /// Verifica si una canción está descargada
    func isDownloaded(_ songID: UUID) async throws -> Bool {
        guard let song = try await songRepository.getByID(songID) else {
            throw DownloadError.songNotFound
        }
        return song.isDownloaded
    }

    /// Obtiene la URL local de una canción descargada
    func getLocalURL(for songID: UUID) -> URL? {
        return cloudStorageRepository.localURL(for: songID)
    }

    /// Obtiene estadísticas de descargas
    func getDownloadStats() async throws -> DownloadStats {
        let songs = try await songRepository.getAll()
        let downloadedSongs = songs.filter { $0.isDownloaded }

        let totalDownloaded = downloadedSongs.count
        let totalSongs = songs.count
        let downloadedDuration = downloadedSongs.compactMap { $0.duration }.reduce(0, +)

        // Calcular tamaño aproximado (estimado en 5MB por canción)
        let estimatedSize = Double(totalDownloaded) * 5.0

        return DownloadStats(
            totalDownloaded: totalDownloaded,
            totalSongs: totalSongs,
            downloadedDuration: downloadedDuration,
            estimatedSizeMB: estimatedSize
        )
    }
}

// MARK: - Download Stats

struct DownloadStats: Sendable {
    let totalDownloaded: Int
    let totalSongs: Int
    let downloadedDuration: TimeInterval
    let estimatedSizeMB: Double

    var downloadPercentage: Double {
        guard totalSongs > 0 else { return 0.0 }
        return Double(totalDownloaded) / Double(totalSongs) * 100.0
    }

    var formattedDuration: String {
        let hours = Int(downloadedDuration) / 3600
        let minutes = (Int(downloadedDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var formattedSize: String {
        if estimatedSizeMB > 1024 {
            return String(format: "%.2f GB", estimatedSizeMB / 1024)
        } else {
            return String(format: "%.0f MB", estimatedSizeMB)
        }
    }
}

// MARK: - Errors

enum DownloadError: Error {
    case songNotFound
    case alreadyDownloaded
    case notDownloaded
    case downloadFailed
    case metadataExtractionFailed
}

// MARK: - Sendable Conformance

extension DownloadUseCases: Sendable {}
