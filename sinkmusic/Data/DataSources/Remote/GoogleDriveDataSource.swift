//
//  GoogleDriveDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer - Remote DataSource
//

import Foundation
import AVFoundation

// Typealias para compatibilidad con código existente
typealias DownloadService = GoogleDriveDataSource
typealias DownloadServiceProtocol = GoogleDriveServiceProtocol

/// Estado mutable de las descargas activas — aislado en un actor para Swift 6
private actor GoogleDriveDownloadState {
    var activeDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>)] = [:]
    var lastReportedProgress: [Int: Int] = [:]

    func addDownload(songID: UUID, continuation: CheckedContinuation<URL, Error>, for id: Int) {
        activeDownloads[id] = (songID, continuation)
    }

    func removeDownload(for id: Int) -> (songID: UUID, continuation: CheckedContinuation<URL, Error>)? {
        lastReportedProgress.removeValue(forKey: id)
        return activeDownloads.removeValue(forKey: id)
    }

    func getDownload(for id: Int) -> (songID: UUID, continuation: CheckedContinuation<URL, Error>)? {
        activeDownloads[id]
    }

    func shouldLogProgress(for id: Int, percent: Int) -> Bool {
        let last = lastReportedProgress[id] ?? -1
        guard percent % 10 == 0 && percent != last else { return false }
        lastReportedProgress[id] = percent
        return true
    }
}

/// DataSource remoto para Google Drive API
/// Implementa GoogleDriveServiceProtocol para abstraer el acceso a archivos en la nube
/// SOLID: Dependency Inversion - Depende de abstracciones (KeychainServiceProtocol, EventBusProtocol)
@MainActor
final class GoogleDriveDataSource: NSObject, GoogleDriveServiceProtocol {

    // MARK: - Dependencies (Inyectadas)

    private let keychainService: KeychainServiceProtocol
    private let eventBus: EventBusProtocol

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol, eventBus: EventBusProtocol) {
        self.keychainService = keychainService
        self.eventBus = eventBus
        super.init()
    }

    // MARK: - Private Properties

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let downloadState = GoogleDriveDownloadState()

    private var apiKey: String? {
        keychainService.googleDriveAPIKey
    }

    private var folderId: String? {
        keychainService.googleDriveFolderId
    }

    // MARK: - Fetch Songs from Folder

    func fetchSongsFromFolder() async throws -> [GoogleDriveFile] {
        guard let apiKey = apiKey else {
            print("❌ ERROR: API Key de Google Drive no configurada")
            throw CloudStorageError.missingAPIKey
        }
        guard let folderId = folderId else {
            print("❌ ERROR: Folder ID de Google Drive no configurado")
            throw CloudStorageError.missingFolderId
        }

        print("📂 Iniciando obtención de canciones desde carpeta Google Drive: \(folderId)")

        var allFiles: [GoogleDriveFile] = []
        var pageToken: String? = nil

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!

            var queryItems = [
                URLQueryItem(name: "q", value: "'\(folderId)' in parents and (mimeType='audio/mpeg' or mimeType='audio/mp4' or mimeType='audio/x-m4a')"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType),nextPageToken"),
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "key", value: apiKey)
            ]

            if let pageToken = pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            components.queryItems = queryItems

            guard let url = components.url else {
                print("❌ URL inválida al listar archivos de Google Drive")
                throw URLError(.badURL)
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ No se recibió respuesta HTTP válida")
                    throw URLError(.badServerResponse)
                }

                print("📡 Google Drive API LIST - Status: \(httpResponse.statusCode) | URL: \(url.absoluteString)")

                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let code = error["code"] as? Int,
                       let message = error["message"] as? String {

                        print("❌ Error de Google Drive API:")
                        print("   Código: \(code)")
                        print("   Mensaje: \(message)")

                        if let errors = error["errors"] as? [[String: Any]],
                           let first = errors.first,
                           let reason = first["reason"] as? String,
                           let domain = first["domain"] as? String {
                            print("   Razón: \(reason)")
                            print("   Dominio: \(domain)")
                        }
                    } else if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Respuesta cruda de error: \(errorString)")
                    }

                    throw URLError(.badServerResponse, userInfo: ["statusCode": httpResponse.statusCode])
                }

                let driveResponse = try JSONDecoder().decode(GoogleDriveResponse.self, from: data)
                allFiles.append(contentsOf: driveResponse.files)
                pageToken = driveResponse.nextPageToken

            } catch {
                print("🚨 Error al obtener lista de canciones:")
                print("   URL: \(url)")
                print("   Error: \(error.localizedDescription)")
                throw error
            }
        } while pageToken != nil

        let m4aFiles = allFiles.filter { $0.name.hasSuffix(".m4a") }
        print("📂 Encontrados \(m4aFiles.count) archivos .m4a en la carpeta")
        return m4aFiles
    }

    // MARK: - Download

    func download(fileID: String, songID: UUID) async throws -> URL {
        guard let apiKey = keychainService.googleDriveAPIKey else {
            print("❌ ERROR: API Key no configurada para descarga")
            await MainActor.run { self.eventBus.emit(.failed(songID: songID, error: "API Key no configurada")) }
            throw CloudStorageError.missingAPIKey
        }

        let downloadURLString = "https://www.googleapis.com/drive/v3/files/\(fileID)?alt=media&key=\(apiKey)"
        guard let url = URL(string: downloadURLString) else {
            print("❌ URL de descarga inválida para fileID: \(fileID)")
            await MainActor.run { self.eventBus.emit(.failed(songID: songID, error: "URL inválida")) }
            throw NSError(domain: "GoogleDriveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL inválida"])
        }

        print("📥 Iniciando descarga de Google Drive:")
        print("   Song ID: \(songID.uuidString)")
        print("   File ID: \(fileID)")
        print("   URL: \(downloadURLString)")

        await MainActor.run { self.eventBus.emit(.started(songID: songID)) }

        let request = URLRequest(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = urlSession.downloadTask(with: request)
            let taskID = downloadTask.taskIdentifier
            Task { [self] in await self.downloadState.addDownload(songID: songID, continuation: continuation, for: taskID) }
            print("   Tarea creada - Task ID: \(taskID)")
            downloadTask.resume()
        }
    }

    // MARK: - Local File Management

    func localURL(for songID: UUID) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let musicDirectory = documentsDirectory.appendingPathComponent("Music")
        do {
            try fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Error al crear directorio Music: \(error.localizedDescription)")
            return nil
        }
        return musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
    }

    func getDuration(for url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            return duration
        } catch {
            print("⚠️ No se pudo obtener duración del audio: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteDownload(for songID: UUID) throws {
        guard let fileURL = localURL(for: songID) else {
            throw NSError(domain: "GoogleDriveService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener URL del archivo"])
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Legacy

    func getDownloadURL(for fileId: String) -> String {
        return "https://drive.google.com/uc?export=download&id=\(fileId)"
    }

    // NOTA: No usar deinit aquí porque:
    // 1. GoogleDriveService se usa como instancia compartida entre ViewModels
    // 2. invalidateAndCancel() cancelaría todas las descargas activas
    // 3. URLSession se limpia automáticamente al finalizar la app
    // 4. Para evitar el retain cycle, se usa weak self en los delegates
}

// MARK: - URLSessionDownloadDelegate

extension GoogleDriveDataSource: URLSessionDownloadDelegate {

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier

        let progress: Double
        let progressPercent: Int
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progressPercent = Int(progress * 100)
        } else {
            let estimatedTotalBytes: Int64 = 10 * 1024 * 1024
            progress = min(0.95, Double(totalBytesWritten) / Double(estimatedTotalBytes))
            progressPercent = Int(progress * 100)
        }

        Task { [weak self] in
            guard let self else { return }
            guard let downloadInfo = await self.downloadState.getDownload(for: taskID) else { return }

            if await self.downloadState.shouldLogProgress(for: taskID, percent: progressPercent) {
                let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
                let downloadedMB = Double(totalBytesWritten) / (1024 * 1024)
                print("📡 Progreso descarga \(taskID): \(String(format: "%.2f", downloadedMB))MB / \(String(format: "%.2f", totalMB))MB (\(progressPercent)%)")
            }

            let songID = downloadInfo.songID
            await MainActor.run { self.eventBus.emit(.progress(songID: songID, progress: progress)) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier

        Task { [weak self] in
            guard let self else { return }
            guard let downloadInfo = await self.downloadState.removeDownload(for: taskID) else { return }

            guard let destinationURL = await self.localURL(for: downloadInfo.songID) else {
                let error = NSError(domain: "GoogleDriveService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear URL de destino"])
                print("❌ No se pudo obtener URL de destino para songID: \(downloadInfo.songID.uuidString)")
                downloadInfo.continuation.resume(throwing: error)
                return
            }

            do {
                let fileSize = try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64 ?? 0
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                print("📦 Descarga completada - Tamaño: \(String(format: "%.2f", fileSizeMB)) MB")

                if fileSize < 100_000 {
                    if let content = try? String(contentsOf: location, encoding: .utf8),
                       content.contains("Google Drive") || content.contains("error") || content.contains("403") {
                        print("❌ Parece una página HTML de error de Google Drive:")
                        print("   Primeros 300 caracteres:\n\(content.prefix(300))")
                    } else {
                        print("⚠️ Archivo muy pequeño (\(String(format: "%.2f", fileSizeMB))MB). Probable error de permisos o archivo no encontrado.")
                    }
                }

                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: location, to: destinationURL)

                do {
                    _ = try AVAudioFile(forReading: destinationURL)
                    print("✅ Verificación de audio exitosa: \(destinationURL.lastPathComponent)")
                } catch {
                    print("⛔️ ERROR: Archivo descargado no es audio válido: \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: destinationURL)
                    throw SyncError.invalidAudioFile
                }

                var mutableURL = destinationURL
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try mutableURL.setResourceValues(resourceValues)

                let songID = downloadInfo.songID
                await MainActor.run { self.eventBus.emit(.completed(songID: songID)) }
                downloadInfo.continuation.resume(returning: destinationURL)
            } catch {
                print("🚨 Error al procesar archivo descargado:")
                print("   Error: \(error.localizedDescription)")
                let songID = downloadInfo.songID
                let errorMessage = error.localizedDescription
                await MainActor.run { self.eventBus.emit(.failed(songID: songID, error: errorMessage)) }
                downloadInfo.continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskIdentifier

        Task { [weak self] in
            guard let self else { return }
            guard let downloadInfo = await self.downloadState.removeDownload(for: taskID) else { return }

            print("❌ Error al completar descarga (task \(taskID)):")
            print("   Descripción: \(error.localizedDescription)")

            if let urlError = error as? URLError {
                print("   URLError code: \(urlError.code.rawValue)")
            }

            let songID = downloadInfo.songID
            let errorMessage = error.localizedDescription
            await MainActor.run { self.eventBus.emit(.failed(songID: songID, error: errorMessage)) }
            downloadInfo.continuation.resume(throwing: error)
        }
    }
}
