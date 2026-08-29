//
//  MegaDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//
//  Facade que implementa MegaServiceProtocol. Coordina API, mapper, descarga y archivos locales.
//

import Foundation
import AVFoundation
import os

@MainActor
final class MegaDataSource: MegaServiceProtocol {

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Mega")

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol
    private let crypto: MegaCrypto
    private let apiClient: MegaAPIClient
    private let downloadSession: MegaDownloadSession
    private let backgroundSessionCompletion: BackgroundSessionCompletionServiceProtocol
    /// Único punto de la app que conoce la ruta `Documents/Music/<uuid>.m4a` (P1.6).
    private let fileStore: DownloadFileStoreProtocol

    // MARK: - State

    /// Handle de la carpeta pública; se guarda al listar y se usa al obtener URL de descarga
    private var publicFolderHandle: String?

    // MARK: - Initialization

    init(
        eventBus: EventBusProtocol,
        backgroundSessionCompletion: BackgroundSessionCompletionServiceProtocol,
        fileStore: DownloadFileStoreProtocol
    ) {
        self.eventBus = eventBus
        self.backgroundSessionCompletion = backgroundSessionCompletion
        self.fileStore = fileStore
        self.crypto = MegaCrypto()
        self.apiClient = MegaAPIClient()
        self.downloadSession = MegaDownloadSession(eventBus: eventBus, completionService: backgroundSessionCompletion)
    }

    deinit {
        downloadSession.invalidate()
    }

    // MARK: - MegaServiceProtocol: Fetch Files

    func fetchFilesFromFolder(folderURL: String) async throws -> [MegaFile] {
        let (nodeId, folderKey) = try crypto.parseFolderURL(folderURL)
        publicFolderHandle = nodeId

        let response = try await apiClient.fetchFolder(nodeId: nodeId)
        let files = MegaFolderMapper.mapToAudioFiles(response: response, folderKey: folderKey, crypto: crypto)

        logger.info("Mega: \(files.count) archivos de audio en carpeta")
        return files
    }

    // MARK: - MegaServiceProtocol: Download

    func download(file: MegaFile, songID: UUID) async throws -> URL {
        eventBus.emit(.started(songID: songID))

        do {
            let downloadURL = try await apiClient.getDownloadURL(fileId: file.id, folderHandle: publicFolderHandle)

            // Se capturan solo valores `Sendable` (file, songID, fileStore) — el closure es
            // `@Sendable` y no debe retener `self` (MainActor).
            let fileStore = self.fileStore
            return try await withCheckedThrowingContinuation { continuation in
                downloadSession.startDownload(
                    url: downloadURL,
                    songID: songID,
                    file: file,
                    continuation: continuation
                ) { encryptedURL in
                    try await MegaDataSource.decryptAndSave(
                        encryptedURL: encryptedURL,
                        file: file,
                        songID: songID,
                        fileStore: fileStore
                    )
                }
            }
        } catch {
            eventBus.emit(.failed(songID: songID, failure: DownloadFailure(error: error)))
            throw error
        }
    }

    /// Desencripta (en streaming, en un hilo de background) y guarda en la ruta canónica
    /// (`DownloadFileStore`). `nonisolated static`: no toca estado del DataSource ni la UI.
    /// No emite `.completed`: el pipeline sigue (metadata + guardado en SwiftData) y ese
    /// evento lo emite `DownloadUseCases` cuando la canción está realmente disponible.
    nonisolated private static func decryptAndSave(
        encryptedURL: URL,
        file: MegaFile,
        songID: UUID,
        fileStore: DownloadFileStoreProtocol
    ) async throws -> URL {
        guard let keyData = Data(base64Encoded: file.decryptionKey) else {
            try? FileManager.default.removeItem(at: encryptedURL)
            throw MegaError.decryptionFailed
        }
        let outputURL = fileStore.fileURL(for: songID)
        do {
            try await Task.detached(priority: .userInitiated) {
                try MegaCrypto().decryptFile(at: encryptedURL, to: outputURL, fileKey: keyData)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: encryptedURL)
            throw error is MegaError ? error : MegaError.decryptionFailed
        }
        try? FileManager.default.removeItem(at: encryptedURL)
        return outputURL
    }

    // MARK: - MegaServiceProtocol: Local File Management

    func localURL(for songID: UUID) -> URL? {
        fileStore.existingFileURL(for: songID)
    }

    func getDuration(for url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return Double(audioFile.length) / audioFile.processingFormat.sampleRate
        } catch {
            return nil
        }
    }

    func deleteDownload(for songID: UUID) throws {
        if let fileURL = fileStore.existingFileURL(for: songID) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
