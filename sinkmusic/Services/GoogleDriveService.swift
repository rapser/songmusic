//
//  GoogleDriveService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import AVFoundation

// Typealias para compatibilidad con código existente
typealias DownloadService = GoogleDriveService
typealias DownloadServiceProtocol = GoogleDriveServiceProtocol

struct GoogleDriveFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String

    var title: String {
        let components = name.components(separatedBy: " - ")
        if components.count >= 2 {
            let titleWithExtension = components[1]
            return titleWithExtension.replacingOccurrences(of: ".m4a", with: "")
        }
        return name.replacingOccurrences(of: ".m4a", with: "")
    }

    var artist: String {
        let components = name.components(separatedBy: " - ")
        if components.count >= 2 {
            return components[0]
        }
        return "Artista Desconocido"
    }
}

struct GoogleDriveResponse: Codable {
    let files: [GoogleDriveFile]
    let nextPageToken: String?
}

enum GoogleDriveError: Error {
    case credentialsNotConfigured
    case missingAPIKey
    case missingFolderId
}

/// Servicio consolidado para interactuar con Google Drive API y manejar descargas
final class GoogleDriveService: NSObject, GoogleDriveServiceProtocol {
    private let keychainService = KeychainService.shared

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let downloadsLock = NSLock()
    private var activeDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>, progressCallback: ((Double) -> Void)?)] = [:]
    private var lastReportedProgress: [Int: Int] = [:]

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
            throw GoogleDriveError.missingAPIKey
        }
        guard let folderId = folderId else {
            print("❌ ERROR: Folder ID de Google Drive no configurado")
            throw GoogleDriveError.missingFolderId
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
                    // Intentar parsear el error de Google Drive
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

    func download(song: Song, progressCallback: ((Double) -> Void)? = nil) async throws -> URL {
        guard let apiKey = keychainService.googleDriveAPIKey else {
            print("❌ ERROR: API Key no configurada para descarga")
            throw GoogleDriveError.missingAPIKey
        }

        let downloadURLString = "https://www.googleapis.com/drive/v3/files/\(song.fileID)?alt=media&key=\(apiKey)"
        guard let url = URL(string: downloadURLString) else {
            print("❌ URL de descarga inválida para fileID: \(song.fileID)")
            throw NSError(domain: "GoogleDriveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL inválida"])
        }

        print("📥 Iniciando descarga de Google Drive:")
        print("   Song ID: \(song.id.uuidString)")
        print("   File ID: \(song.fileID)")
        print("   URL: \(downloadURLString)")

        let request = URLRequest(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = urlSession.downloadTask(with: request)
            downloadsLock.lock()
            activeDownloads[downloadTask.taskIdentifier] = (song.id, continuation, progressCallback)
            downloadsLock.unlock()
            
            print("   Tarea creada - Task ID: \(downloadTask.taskIdentifier)")
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
}

// MARK: - URLSessionDownloadDelegate

extension GoogleDriveService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadsLock.lock()
        guard let downloadInfo = activeDownloads[downloadTask.taskIdentifier] else {
            downloadsLock.unlock()
            return
        }
        downloadsLock.unlock()

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let progressPercent = Int(progress * 100)

            // Solo imprimir en consola cada 10% para no saturar logs
            if progressPercent % 10 == 0 && progressPercent != (lastReportedProgress[downloadTask.taskIdentifier] ?? -1) {
                let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
                let downloadedMB = Double(totalBytesWritten) / (1024 * 1024)
                print("📡 Progreso descarga \(downloadTask.taskIdentifier): \(String(format: "%.2f", downloadedMB))MB / \(String(format: "%.2f", totalMB))MB (\(progressPercent)%)")
                lastReportedProgress[downloadTask.taskIdentifier] = progressPercent
            }
        } else {
            let estimatedTotalBytes: Int64 = 10 * 1024 * 1024 // 10MB
            progress = min(0.95, Double(totalBytesWritten) / Double(estimatedTotalBytes))
            let progressPercent = Int(progress * 100)

            if progressPercent % 10 == 0 && progressPercent != (lastReportedProgress[downloadTask.taskIdentifier] ?? -1) {
                let downloadedMB = Double(totalBytesWritten) / (1024 * 1024)
                print("📡 Progreso (estimado) \(downloadTask.taskIdentifier): \(String(format: "%.2f", downloadedMB))MB (\(progressPercent)%)")
                lastReportedProgress[downloadTask.taskIdentifier] = progressPercent
            }
        }

        // SIEMPRE reportar al callback para que se actualice en tiempo real
        if let progressCallback = downloadInfo.progressCallback {
            Task { @MainActor in
                progressCallback(progress)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadsLock.lock()
        guard let downloadInfo = activeDownloads.removeValue(forKey: downloadTask.taskIdentifier) else {
            downloadsLock.unlock()
            return
        }
        downloadsLock.unlock()

        guard let destinationURL = localURL(for: downloadInfo.songID) else {
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

            // Verificación de integridad
            do {
                _ = try AVAudioFile(forReading: destinationURL)
                print("✅ Verificación de audio exitosa: \(destinationURL.lastPathComponent)")
            } catch {
                print("⛔️ ERROR: Archivo descargado no es audio válido: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: destinationURL)
                throw SyncError.invalidAudioFile // Asume que tienes este error definido
            }

            // Evitar backup en iCloud
            var mutableURL = destinationURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)

            downloadInfo.continuation.resume(returning: destinationURL)
        } catch {
            print("🚨 Error al procesar archivo descargado:")
            print("   Error: \(error.localizedDescription)")
            downloadInfo.continuation.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        downloadsLock.lock()
        guard let downloadInfo = activeDownloads.removeValue(forKey: task.taskIdentifier) else {
            downloadsLock.unlock()
            return
        }
        downloadsLock.unlock()

        if let error = error {
            print("❌ Error al completar descarga (task \(task.taskIdentifier)):")
            print("   Descripción: \(error.localizedDescription)")

            if let urlError = error as? URLError {
                print("   URLError code: \(urlError.code.rawValue)")
                print("   Detalle: \(urlError.localizedDescription)")
            }

            if let nsError = error as NSError? {
                print("   Dominio: \(nsError.domain)")
                print("   Código: \(nsError.code)")
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("   Error subyacente: \(underlying)")
                }
            }

            if let httpResponse = task.response as? HTTPURLResponse {
                print("   HTTP Status: \(httpResponse.statusCode)")
            }

            downloadInfo.continuation.resume(throwing: error)
        }
    }
}
