//
//  MegaDownloadSession.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//
//  Gestiona descargas con URLSession y reporte de progreso.
//  Al finalizar, entrega los datos al callback para desencriptar y guardar (fuera de aquí).
//

import Foundation

/// Información de una descarga en curso
struct MegaDownloadTaskInfo {
    let songID: UUID
    let file: MegaFile
    let continuation: CheckedContinuation<URL, Error>
    let decryptAndSave: (Data) async throws -> URL
}

/// Session de descarga con progreso. Implementa URLSessionDownloadDelegate.
final class MegaDownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let eventBus: EventBusProtocol

    private let lock = NSLock()
    private var activeTasks: [Int: MegaDownloadTaskInfo] = [:]
    private var lastReportedProgressPercent: [Int: Int] = [:]

    private var session: URLSession!

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
        super.init()
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 600
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Inicia una descarga. El progreso se emite por EventBus. Al terminar se llama decryptAndSave con los datos.
    func startDownload(
        url: URL,
        songID: UUID,
        file: MegaFile,
        continuation: CheckedContinuation<URL, Error>,
        decryptAndSave: @escaping (Data) async throws -> URL
    ) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 600
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.downloadTask(with: request)
        let info = MegaDownloadTaskInfo(
            songID: songID,
            file: file,
            continuation: continuation,
            decryptAndSave: decryptAndSave
        )
        lock.lock()
        activeTasks[task.taskIdentifier] = info
        lock.unlock()
        task.resume()
    }

    func invalidate() {
        session.invalidateAndCancel()
    }

    deinit {
        invalidate()
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        guard let info = activeTasks[downloadTask.taskIdentifier] else {
            lock.unlock()
            return
        }
        let songID = info.songID
        lock.unlock()

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = min(0.99, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        } else {
            progress = min(0.95, Double(totalBytesWritten) / Double(10 * 1024 * 1024))
        }

        let percent = Int(progress * 100)
        lock.lock()
        let last = lastReportedProgressPercent[downloadTask.taskIdentifier] ?? -1
        let shouldEmit = percent >= last + 2 || percent == 0 || progress >= 0.99
        if shouldEmit {
            lastReportedProgressPercent[downloadTask.taskIdentifier] = percent
        }
        lock.unlock()

        if shouldEmit {
            Task { @MainActor in
                eventBus.emit(.progress(songID: songID, progress: progress))
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        guard let info = activeTasks.removeValue(forKey: downloadTask.taskIdentifier) else {
            lock.unlock()
            return
        }
        lastReportedProgressPercent.removeValue(forKey: downloadTask.taskIdentifier)
        lock.unlock()

        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: location)
        } catch {
            Task { @MainActor in
                eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription))
            }
            info.continuation.resume(throwing: error)
            return
        }

        Task {
            do {
                let localURL = try await info.decryptAndSave(encryptedData)
                info.continuation.resume(returning: localURL)
            } catch {
                Task { @MainActor in
                    eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription))
                }
                info.continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        lock.lock()
        guard let info = activeTasks.removeValue(forKey: task.taskIdentifier) else {
            lock.unlock()
            return
        }
        lastReportedProgressPercent.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        Task { @MainActor in
            eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription))
        }
        info.continuation.resume(throwing: error)
    }
}
