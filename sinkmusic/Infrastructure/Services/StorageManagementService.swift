//
//  StorageManagementService.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import Foundation
import SwiftData

// MARK: - Storage Management Service (Single Responsibility)

/// Servicio responsable de gestionar el almacenamiento de canciones descargadas
/// SOLID: Dependency Inversion - Depende de GoogleDriveServiceProtocol (abstracción)
final class StorageManagementService: StorageManagementServiceProtocol, SettingsServiceProtocol {
    nonisolated(unsafe) private let googleDriveService: GoogleDriveServiceProtocol

    nonisolated init(googleDriveService: GoogleDriveServiceProtocol) {
        self.googleDriveService = googleDriveService
    }

    // MARK: - SettingsServiceProtocol

    func calculateStorageUsed(for songs: [Song]) -> String {
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
                    // Continuar con el siguiente archivo si hay error
                    continue
                }
            }
        }

        return formatBytes(totalSize)
    }

    func filterPendingSongs(_ songs: [Song]) -> [Song] {
        songs.filter { !$0.isDownloaded }
    }

    func filterDownloadedSongs(_ songs: [Song]) -> [Song] {
        songs.filter { $0.isDownloaded }
    }

    @MainActor
    func deleteAllDownloads(
        songs: [Song],
        modelContext: ModelContext
    ) async throws {
        let downloadedSongs = filterDownloadedSongs(songs)

        for song in downloadedSongs {
            // Eliminar el archivo descargado
            try? googleDriveService.deleteDownload(for: song.id)

            // Buscar el DTO correspondiente en el ModelContext y actualizar
            let songID = song.id
            let descriptor = FetchDescriptor<SongDTO>(
                predicate: #Predicate { $0.id == songID }
            )
            if let songDTO = try? modelContext.fetch(descriptor).first {
                songDTO.isDownloaded = false
                songDTO.duration = nil
                songDTO.artworkData = nil
                songDTO.album = nil
                songDTO.author = nil
            }
        }

        // Guardar todos los cambios
        try modelContext.save()
    }

    // MARK: - Private Helpers

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

// MARK: - Sendable Conformance

extension StorageManagementService: Sendable {}
