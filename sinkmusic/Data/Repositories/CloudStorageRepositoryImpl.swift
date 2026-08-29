//
//  CloudStorageRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation
import os
import AVFoundation

/// Implementación del repositorio de Cloud Storage
/// Usa patrón Strategy para soportar múltiples proveedores (Google Drive, Mega)
@MainActor
final class CloudStorageRepositoryImpl: CloudStorageRepositoryProtocol {

    // MARK: - Dependencies

    private let googleDriveDataSource: GoogleDriveServiceProtocol
    private let megaDataSource: MegaServiceProtocol
    private let songLocalDataSource: SongLocalDataSource
    private let credentialsRepository: CredentialsRepositoryProtocol
    private let fileStore: DownloadFileStoreProtocol

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "CloudStorage")

    // MARK: - State

    /// Cache de archivos de Mega para obtener la clave de desencriptación
    private var megaFilesCache: [String: MegaFile] = [:]

    // MARK: - Initialization

    init(
        googleDriveDataSource: GoogleDriveServiceProtocol,
        megaDataSource: MegaServiceProtocol,
        songLocalDataSource: SongLocalDataSource,
        credentialsRepository: CredentialsRepositoryProtocol,
        fileStore: DownloadFileStoreProtocol
    ) {
        self.googleDriveDataSource = googleDriveDataSource
        self.megaDataSource = megaDataSource
        self.songLocalDataSource = songLocalDataSource
        self.credentialsRepository = credentialsRepository
        self.fileStore = fileStore
    }

    // MARK: - CloudStorageRepositoryProtocol

    func fetchSongsFromFolder() async throws -> [CloudFile] {
        let provider = credentialsRepository.getSelectedCloudProvider()

        do {
            switch provider {
            case .googleDrive:
                let source = googleDriveDataSource
                let googleDriveFiles = try await source.fetchSongsFromFolder()
                return CloudFileMapper.toDomain(from: googleDriveFiles)

            case .mega:
                let folderURL = credentialsRepository.loadMegaFolderURL()
                guard !folderURL.isEmpty else {
                    throw CloudStorageError.credentialsNotConfigured
                }

                let megaFiles = try await megaDataSource.fetchFilesFromFolder(folderURL: folderURL)

                // Cachear archivos para tener acceso a la clave de desencriptación
                megaFilesCache = Dictionary(uniqueKeysWithValues: megaFiles.map { ($0.id, $0) })
                logger.debug("MEGA Cache actualizado con \(self.megaFilesCache.count) archivos")

                return CloudFileMapper.toDomain(from: megaFiles)
            }
        } catch {
            // Frontera de la capa Data: el resto de la app recibe un `SyncError` tipado,
            // no un `URLError`/`NSError` crudo que haya que clasificar por texto.
            throw SyncError.from(error)
        }
    }

    func download(
        fileID: String,
        songID: UUID
    ) async throws -> URL {
        let provider = credentialsRepository.getSelectedCloudProvider()

        switch provider {
        case .googleDrive:
            let source = googleDriveDataSource
            return try await source.download(
                fileID: fileID,
                songID: songID
            )

        case .mega:
            // Verificar si el cache está vacío y rellenarlo si es necesario
            if megaFilesCache.isEmpty {
                logger.debug("Cache de MEGA vacío, rellenando...")
                let folderURL = credentialsRepository.loadMegaFolderURL()
                guard !folderURL.isEmpty else {
                    throw CloudStorageError.credentialsNotConfigured
                }
                
                let megaFiles = try await megaDataSource.fetchFilesFromFolder(folderURL: folderURL)
                megaFilesCache = Dictionary(uniqueKeysWithValues: megaFiles.map { ($0.id, $0) })
                logger.debug("MEGA Cache rellenado con \(self.megaFilesCache.count) archivos")
            }
            
            guard let megaFile = megaFilesCache[fileID] else {
                logger.error("Archivo no encontrado en cache MEGA: \(fileID)")
                throw CloudStorageError.fileNotFound
            }
            logger.debug("Archivo encontrado en cache MEGA: \(megaFile.name)")

            return try await megaDataSource.download(
                file: megaFile,
                songID: songID
            )
        }
    }

    /// La lectura del archivo (`AVAudioFile`) se hace en un hilo de background: antes corría
    /// en el MainActor dentro del pipeline de descarga. El proveedor ya no importa aquí
    /// (ambos DataSources hacían exactamente la misma lectura).
    nonisolated func getDuration(for url: URL) async -> TimeInterval? {
        await Task.detached(priority: .utility) {
            guard let file = try? AVAudioFile(forReading: url) else { return nil }
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { return nil }
            return Double(file.length) / sampleRate
        }.value
    }

    func deleteDownload(for songID: UUID) throws {
        let provider = credentialsRepository.getSelectedCloudProvider()

        switch provider {
        case .googleDrive:
            try googleDriveDataSource.deleteDownload(for: songID)
        case .mega:
            try megaDataSource.deleteDownload(for: songID)
        }
    }

    func localURL(for songID: UUID) -> URL? {
        // La ruta ya no depende del proveedor: ambos DataSources escriben en la misma
        // ubicación canónica (`DownloadFileStore`). Antes esto hacía un switch por proveedor.
        fileStore.existingFileURL(for: songID)
    }
}

