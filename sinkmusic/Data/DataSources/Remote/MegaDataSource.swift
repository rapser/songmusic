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

@MainActor
final class MegaDataSource: MegaServiceProtocol {

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol
    private let crypto: MegaCrypto
    private let apiClient: MegaAPIClient
    private let downloadSession: MegaDownloadSession

    // MARK: - State

    private let musicDirectory: URL
    /// Handle de la carpeta pública; se guarda al listar y se usa al obtener URL de descarga
    private var publicFolderHandle: String?

    // MARK: - Initialization

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
        self.crypto = MegaCrypto()
        self.apiClient = MegaAPIClient()
        self.downloadSession = MegaDownloadSession(eventBus: eventBus)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.musicDirectory = documents.appendingPathComponent("Music")

        try? FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
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

        print("📁 Mega: \(files.count) archivos de audio en carpeta")
        return files
    }

    // MARK: - MegaServiceProtocol: Download

    func download(file: MegaFile, songID: UUID) async throws -> URL {
        eventBus.emit(.started(songID: songID))

        do {
            let downloadURL = try await apiClient.getDownloadURL(fileId: file.id, folderHandle: publicFolderHandle)

            return try await withCheckedThrowingContinuation { continuation in
                downloadSession.startDownload(
                    url: downloadURL,
                    songID: songID,
                    file: file,
                    continuation: continuation
                ) { [weak self] encryptedData in
                    guard let self else { throw MegaError.downloadFailed("DataSource no disponible") }
                    return try await self.decryptAndSave(encryptedData: encryptedData, file: file, songID: songID)
                }
            }
        } catch {
            eventBus.emit(.failed(songID: songID, error: error.localizedDescription))
            throw error
        }
    }

    /// Desencripta los datos y los guarda en musicDirectory; emite .completed
    private func decryptAndSave(encryptedData: Data, file: MegaFile, songID: UUID) async throws -> URL {
        guard let keyData = Data(base64Encoded: file.decryptionKey),
              let decrypted = crypto.decryptFile(encryptedData: encryptedData, fileKey: keyData) else {
            throw MegaError.decryptionFailed
        }
        let localURL = musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
        // Escritura atómica: evita que se lea el archivo antes de que esté completo en disco
        try decrypted.write(to: localURL, options: [.atomic])
        eventBus.emit(.completed(songID: songID))
        return localURL
    }

    // MARK: - MegaServiceProtocol: Local File Management

    func localURL(for songID: UUID) -> URL? {
        let fileURL = musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
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
        let fileURL = musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
