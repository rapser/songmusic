//
//  GoogleDriveService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import AVFoundation

// Typealias para compatibilidad con código existente
// DownloadService ahora es GoogleDriveService
typealias DownloadService = GoogleDriveService
typealias DownloadServiceProtocol = GoogleDriveServiceProtocol

struct GoogleDriveFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String

    var title: String {
        // Extraer el título del nombre del archivo (sin extensión)
        let components = name.components(separatedBy: " - ")
        if components.count >= 2 {
            // Formato esperado: "Artista - Título.m4a"
            let titleWithExtension = components[1]
            return titleWithExtension.replacingOccurrences(of: ".m4a", with: "")
        }
        return name.replacingOccurrences(of: ".m4a", with: "")
    }

    var artist: String {
        // Extraer el artista del nombre del archivo
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
/// Implementa GoogleDriveServiceProtocol cumpliendo con SOLID
final class GoogleDriveService: NSObject, GoogleDriveServiceProtocol {
    private let keychainService = KeychainService.shared

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        // Reducir el tamaño del buffer para reportar progreso más frecuentemente
        // Esto hace que URLSession reporte progreso cada 64KB en lugar de esperar chunks grandes
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Thread-safe dictionary para descargas activas
    private let downloadsLock = NSLock()
    private var activeDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>, progressCallback: ((Double) -> Void)?)] = [:]

    // Último progreso reportado por cada tarea (para evitar spam de logs)
    private var lastReportedProgress: [Int: Int] = [:]

    private var apiKey: String? {
        keychainService.googleDriveAPIKey
    }

    private var folderId: String? {
        keychainService.googleDriveFolderId
    }

    // MARK: - Fetch Songs from Folder

    /// Obtener lista de archivos de la carpeta pública de Google Drive
    func fetchSongsFromFolder() async throws -> [GoogleDriveFile] {
        // Verificar que las credenciales estén configuradas
        guard let apiKey = apiKey else {
            throw GoogleDriveError.missingAPIKey
        }

        guard let folderId = folderId else {
            throw GoogleDriveError.missingFolderId
        }

        var allFiles: [GoogleDriveFile] = []
        var pageToken: String? = nil

        // Iterar sobre todas las páginas de resultados
        repeat {
            // URL de la API de Google Drive Files.list
            // Usando acceso público sin autenticación para carpetas compartidas
            let urlString = "https://www.googleapis.com/drive/v3/files"

            guard var components = URLComponents(string: urlString) else {
                throw URLError(.badURL)
            }

            // Parámetros de consulta
            var queryItems = [
                URLQueryItem(name: "q", value: "'\(folderId)' in parents and (mimeType='audio/mpeg' or mimeType='audio/mp4' or mimeType='audio/x-m4a')"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType),nextPageToken"),
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "key", value: apiKey)
            ]

            // Agregar pageToken si existe
            if let pageToken = pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            components.queryItems = queryItems

            guard let url = components.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }

            let driveResponse = try JSONDecoder().decode(GoogleDriveResponse.self, from: data)

            // Agregar archivos de esta página
            allFiles.append(contentsOf: driveResponse.files)

            // Actualizar pageToken para la siguiente iteración
            pageToken = driveResponse.nextPageToken

        } while pageToken != nil

        // Filtrar solo archivos .m4a
        let m4aFiles = allFiles.filter { file in
            file.name.hasSuffix(".m4a")
        }

        return m4aFiles
    }

    // MARK: - Download

    /// Descarga un archivo de Google Drive con callback de progreso
    func download(song: Song, progressCallback: ((Double) -> Void)? = nil) async throws -> URL {
        // Obtener API Key del Keychain
        guard let apiKey = keychainService.googleDriveAPIKey else {
            throw GoogleDriveError.missingAPIKey
        }

        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(song.fileID)?alt=media&key=\(apiKey)") else {
            throw NSError(domain: "GoogleDriveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL de la API inválida"])
        }

        let request = URLRequest(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = urlSession.downloadTask(with: request)
            downloadsLock.lock()
            activeDownloads[downloadTask.taskIdentifier] = (song.id, continuation, progressCallback)
            downloadsLock.unlock()
            downloadTask.resume()
        }
    }

    // MARK: - Local File Management

    /// Obtiene la URL local donde se guarda un archivo descargado
    func localURL(for songID: UUID) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let musicDirectory = documentsDirectory.appendingPathComponent("Music")
        do {
            try fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        return musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
    }

    /// Obtiene la duración de un archivo de audio
    func getDuration(for url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            return duration
        } catch {
            return nil
        }
    }

    /// Elimina el archivo descargado
    func deleteDownload(for songID: UUID) throws {
        guard let fileURL = localURL(for: songID) else {
            throw NSError(domain: "GoogleDriveService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener la URL del archivo"])
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Legacy (for compatibility)

    /// Construir URL de descarga directa para un archivo de Google Drive
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
            // Progreso normal cuando conocemos el tamaño total
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

            // Solo imprimir logs cada 10% para no saturar la consola
            let progressPercent = Int(progress * 100)
            let lastPercent = lastReportedProgress[downloadTask.taskIdentifier] ?? -1
            if progressPercent % 10 == 0 && progressPercent != lastPercent {
                let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
                let downloadedMB = Double(totalBytesWritten) / (1024 * 1024)
                print("📡 GoogleDrive: \(String(format: "%.2f", downloadedMB))MB / \(String(format: "%.2f", totalMB))MB (\(progressPercent)%)")
                lastReportedProgress[downloadTask.taskIdentifier] = progressPercent
            }
        } else {
            // Si no conocemos el total, estimamos basándonos en un tamaño promedio de canción (10MB)
            let estimatedTotalBytes: Int64 = 10 * 1024 * 1024 // 10MB
            progress = min(0.95, Double(totalBytesWritten) / Double(estimatedTotalBytes))

            let progressPercent = Int(progress * 100)
            let lastPercent = lastReportedProgress[downloadTask.taskIdentifier] ?? -1
            if progressPercent % 10 == 0 && progressPercent != lastPercent {
                let downloadedMB = Double(totalBytesWritten) / (1024 * 1024)
                print("📡 GoogleDrive: \(String(format: "%.2f", downloadedMB))MB descargados (estimado: \(progressPercent)%)")
                lastReportedProgress[downloadTask.taskIdentifier] = progressPercent
            }
        }

        // IMPORTANTE: Llamar al callback SIEMPRE, no solo cuando imprimimos logs
        // El UI necesita todas las actualizaciones de progreso
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
            let error = NSError(domain: "GoogleDriveService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la URL de destino."])
            downloadInfo.continuation.resume(throwing: error)
            return
        }

        do {
            // Validar que el archivo descargado sea suficientemente grande para ser un archivo de audio
            let fileSize = try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize) / (1024 * 1024)

            print("📦 Archivo descargado: \(String(format: "%.2f", fileSizeMB))MB")

            // Si el archivo es menor a 100KB, probablemente sea un error HTML de Google Drive
            if fileSize < 100_000 {
                print("⚠️ ADVERTENCIA: Archivo muy pequeño (\(String(format: "%.2f", fileSizeMB))MB). Puede ser un error de Google Drive.")
                print("💡 Verifica que el archivo tenga permisos públicos en Google Drive")
            }

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)

            // Evitar backup en iCloud
            var mutableURL = destinationURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)

            downloadInfo.continuation.resume(returning: destinationURL)
        } catch {
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
            downloadInfo.continuation.resume(throwing: error)
        }
    }
}
