
import Foundation
import Combine

// Servicio dedicado a la descarga de archivos
class DownloadService: NSObject {
    
    // Publisher para el progreso de la descarga
    var downloadProgressPublisher = PassthroughSubject<(songID: UUID, progress: Double), Never>()

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // Usamos un diccionario para mapear tareas a sus continuaciones y IDs
    private var activeDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>)] = [:]

    func download(song: Song) async throws -> URL {
        let apiKey = "AIzaSyB6_cJHOqvf9hNvdj8xj51K2lyQYohl1Sw"
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(song.fileID)?alt=media&key=\(apiKey)") else {
            throw NSError(domain: "DownloadService", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL de la API inválida"])
        }
        
        print("⬇️ Iniciando descarga con API para: \(song.title) desde \(url)")
        
        let request = URLRequest(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = urlSession.downloadTask(with: request)
            activeDownloads[downloadTask.taskIdentifier] = (song.id, continuation)
            downloadTask.resume()
        }
    }

    func localURL(for songID: UUID) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let musicDirectory = documentsDirectory.appendingPathComponent("Music")
        do {
            try fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error al crear directorio: \(error)")
            return nil
        }
        return musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
    }
}

extension DownloadService: URLSessionDownloadDelegate {
    
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
            let error = NSError(domain: "DownloadService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la URL de destino."])
            downloadInfo.continuation.resume(throwing: error)
            return
        }
        
        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            print("✅ Descarga completa para la canción ID: \(downloadInfo.songID)")
            downloadInfo.continuation.resume(returning: destinationURL)
        } catch {
            downloadInfo.continuation.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadInfo = activeDownloads.removeValue(forKey: task.taskIdentifier) else { return }
        
        if let error = error {
            print("❌ Error en la descarga para la canción ID: \(downloadInfo.songID). Error: \(error.localizedDescription)")
            downloadInfo.continuation.resume(throwing: error)
        }
    }
}
