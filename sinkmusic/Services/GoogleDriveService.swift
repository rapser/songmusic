//
//  GoogleDriveService.swift
//  sinkmusic
//
//  Created by Claude Code
//

import Foundation
import Combine
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

    // Publisher para el progreso de la descarga
    var downloadProgressPublisher = PassthroughSubject<(songID: UUID, progress: Double), Never>()

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Usamos un diccionario para mapear tareas a sus continuaciones y IDs
    private var activeDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>)] = [:]

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

        // URL de la API de Google Drive Files.list
        // Usando acceso público sin autenticación para carpetas compartidas
        let urlString = "https://www.googleapis.com/drive/v3/files"

        guard var components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }

        // Parámetros de consulta
        components.queryItems = [
            URLQueryItem(name: "q", value: "'\(folderId)' in parents and (mimeType='audio/mpeg' or mimeType='audio/mp4' or mimeType='audio/x-m4a')"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

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

        // Filtrar solo archivos .m4a
        let m4aFiles = driveResponse.files.filter { file in
            file.name.hasSuffix(".m4a")
        }

        return m4aFiles
    }

    // MARK: - Download

    /// Descarga un archivo de Google Drive
    func download(song: Song) async throws -> URL {
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
            activeDownloads[downloadTask.taskIdentifier] = (song.id, continuation)
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
        guard let downloadInfo = activeDownloads[downloadTask.taskIdentifier] else { return }

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            // Si no conocemos el total, enviamos -1 para indicar progreso indeterminado
            progress = -1
        }
        downloadProgressPublisher.send((songID: downloadInfo.songID, progress: progress))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadInfo = activeDownloads.removeValue(forKey: downloadTask.taskIdentifier) else { return }

        guard let destinationURL = localURL(for: downloadInfo.songID) else {
            let error = NSError(domain: "GoogleDriveService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la URL de destino."])
            downloadInfo.continuation.resume(throwing: error)
            return
        }

        do {
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
        guard let downloadInfo = activeDownloads.removeValue(forKey: task.taskIdentifier) else { return }

        if let error = error {
            downloadInfo.continuation.resume(throwing: error)
        }
    }
}
