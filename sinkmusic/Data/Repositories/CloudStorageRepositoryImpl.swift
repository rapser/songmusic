//
//  CloudStorageRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Cloud Storage
/// Usa patrón Strategy para soportar múltiples proveedores (Google Drive, Mega)
@MainActor
final class CloudStorageRepositoryImpl: CloudStorageRepositoryProtocol {

    // MARK: - Dependencies

    private let googleDriveDataSource: GoogleDriveServiceProtocol
    private let megaDataSource: MegaServiceProtocol
    private let songLocalDataSource: SongLocalDataSource
    private let credentialsRepository: CredentialsRepositoryProtocol

    // MARK: - State

    /// Cache de archivos de Mega para obtener la clave de desencriptación
    private var megaFilesCache: [String: MegaFile] = [:]

    // MARK: - Initialization

    init(
        googleDriveDataSource: GoogleDriveServiceProtocol,
        megaDataSource: MegaServiceProtocol,
        songLocalDataSource: SongLocalDataSource,
        credentialsRepository: CredentialsRepositoryProtocol
    ) {
        self.googleDriveDataSource = googleDriveDataSource
        self.megaDataSource = megaDataSource
        self.songLocalDataSource = songLocalDataSource
        self.credentialsRepository = credentialsRepository
    }

    // MARK: - CloudStorageRepositoryProtocol

    func fetchSongsFromFolder() async throws -> [CloudFile] {
        let provider = credentialsRepository.getSelectedCloudProvider()

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
            print("📦 MEGA Cache actualizado con \(megaFilesCache.count) archivos")
            print("🔑 IDs en cache: \(megaFilesCache.keys.sorted().prefix(3).joined(separator: ", "))...")

            return CloudFileMapper.toDomain(from: megaFiles)
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
                print("⚠️ Cache de MEGA vacío, rellenando...")
                let folderURL = credentialsRepository.loadMegaFolderURL()
                guard !folderURL.isEmpty else {
                    throw CloudStorageError.credentialsNotConfigured
                }
                
                let megaFiles = try await megaDataSource.fetchFilesFromFolder(folderURL: folderURL)
                megaFilesCache = Dictionary(uniqueKeysWithValues: megaFiles.map { ($0.id, $0) })
                print("📦 MEGA Cache rellenado con \(megaFilesCache.count) archivos")
            }
            
            // Obtener archivo del cache para tener la clave de desencriptación
            print("🔍 Buscando archivo en cache MEGA")
            print("   FileID solicitado: \(fileID)")
            print("   Cache size: \(megaFilesCache.count)")
            print("   IDs en cache: \(megaFilesCache.keys.sorted().prefix(5).joined(separator: ", "))")
            
            guard let megaFile = megaFilesCache[fileID] else {
                print("❌ Archivo NO encontrado en cache")
                print("   ¿El fileID existe en cache? \(megaFilesCache.keys.contains(fileID))")
                throw CloudStorageError.fileNotFound
            }
            
            print("✅ Archivo encontrado en cache: \(megaFile.name)")

            return try await megaDataSource.download(
                file: megaFile,
                songID: songID
            )
        }
    }

    func getDuration(for url: URL) -> TimeInterval? {
        let provider = credentialsRepository.getSelectedCloudProvider()

        switch provider {
        case .googleDrive:
            return googleDriveDataSource.getDuration(for: url)
        case .mega:
            return megaDataSource.getDuration(for: url)
        }
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
        let provider = credentialsRepository.getSelectedCloudProvider()

        switch provider {
        case .googleDrive:
            return googleDriveDataSource.localURL(for: songID)
        case .mega:
            return megaDataSource.localURL(for: songID)
        }
    }
}

