//
//  DownloadUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation
import os

/// Casos de uso agrupados para descarga de canciones
/// Gestiona descarga, extracción de metadata y almacenamiento
@MainActor
final class DownloadUseCases {

    // MARK: - Dependencies

    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol
    private let credentialsRepository: CredentialsRepositoryProtocol
    private let eventBus: EventBusProtocol

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Download")

    // MARK: - Initialization

    init(
        songRepository: SongRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol,
        credentialsRepository: CredentialsRepositoryProtocol,
        eventBus: EventBusProtocol
    ) {
        self.songRepository = songRepository
        self.cloudStorageRepository = cloudStorageRepository
        self.metadataRepository = metadataRepository
        self.credentialsRepository = credentialsRepository
        self.eventBus = eventBus
    }

    // MARK: - Provider

    /// Proveedor de almacenamiento cloud actualmente seleccionado.
    /// Los ViewModels consultan esto a través del UseCase, sin acceder al repositorio directamente.
    func currentCloudProvider() -> CloudStorageProvider {
        credentialsRepository.getSelectedCloudProvider()
    }

    /// Capacidades del proveedor activo.
    /// Permite a ViewModels adaptarse sin acoplarse al enum `CloudStorageProvider`.
    func currentProviderCapabilities() -> CloudProviderCapabilities {
        switch credentialsRepository.getSelectedCloudProvider() {
        case .googleDrive:
            return CloudProviderCapabilities(
                displayName: "Google Drive",
                supportsQuotaTracking: false,
                quotaAlertMessage: "",
                maxConcurrentDownloads: 1
            )
        case .mega:
            return CloudProviderCapabilities(
                displayName: "Mega",
                supportsQuotaTracking: true,
                quotaAlertMessage: "Has alcanzado el límite de transferencia diario de Mega.",
                maxConcurrentDownloads: 3
            )
        }
    }

    // MARK: - Constants

    private static let estimatedFileSizeMB: Double = 5.0

    // MARK: - Download Operations

    /// Descarga una canción desde el almacenamiento cloud.
    ///
    /// El progreso cubre TODO el pipeline, no solo la transferencia de red:
    /// - 0.00–0.90  descarga de red (emitido por el DataSource)
    /// - 0.90–0.95  desencriptado/verificación + escritura del archivo (DataSource)
    /// - 0.97       extracción de metadata (emitido aquí)
    /// - .completed recién cuando la canción quedó guardada en SwiftData y disponible
    func downloadSong(_ songID: UUID) async throws {
        guard var song = try await songRepository.getByID(songID) else {
            throw DownloadError.songNotFound
        }

        if song.isDownloaded {
            throw DownloadError.alreadyDownloaded
        }

        // Descargar archivo (el progreso 0–95% se emite via EventBus desde el DataSource)
        let localURL = try await cloudStorageRepository.download(
            fileID: song.fileID,
            songID: songID
        )

        // Fase de metadata: el archivo ya está en disco pero la canción aún no está lista
        eventBus.emit(DownloadEvent.progress(songID: songID, progress: 0.97))

        // Extraer metadata
        if let metadata = await metadataRepository.extractMetadata(from: localURL) {
            // Actualizar canción con metadata
            song = Song(
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
            song = Song(
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

        // Actualizar en la base de datos — solo después de esto la canción está
        // realmente disponible (SwiftData con isDownloaded = true)
        do {
            try await songRepository.update(song)
        } catch {
            eventBus.emit(DownloadEvent.failed(songID: songID, error: error.localizedDescription))
            throw error
        }

        eventBus.emit(DownloadEvent.completed(songID: songID))
    }

    /// Descarga múltiples canciones y reporta éxitos y fallos individualmente.
    /// A diferencia de la versión anterior, no silencia los errores —
    /// el llamador recibe un `BatchResult` con la lista exacta de fallos.
    func downloadMultipleSongs(_ songIDs: [UUID]) async -> BatchResult<UUID> {
        var succeeded: [UUID] = []
        var failed: [(id: UUID, error: Error)] = []

        for songID in songIDs {
            do {
                try await downloadSong(songID)
                succeeded.append(songID)
            } catch {
                logger.warning("Error al descargar canción \(songID): \(error)")
                failed.append((id: songID, error: error))
            }
        }
        return BatchResult(succeeded: succeeded, failed: failed)
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
        song = Song(
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

        let estimatedSize = Double(totalDownloaded) * DownloadUseCases.estimatedFileSizeMB

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
