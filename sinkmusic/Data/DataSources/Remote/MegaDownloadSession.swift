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

/// Estado mutable de las descargas activas — aislado en un actor para Swift 6
private actor MegaDownloadState {
    var activeTasks: [Int: MegaDownloadTaskInfo] = [:]
    var lastReportedProgressPercent: [Int: Int] = [:]

    func addTask(_ info: MegaDownloadTaskInfo, for id: Int) {
        activeTasks[id] = info
    }

    func removeTask(for id: Int) -> MegaDownloadTaskInfo? {
        lastReportedProgressPercent.removeValue(forKey: id)
        return activeTasks.removeValue(forKey: id)
    }

    func getTask(for id: Int) -> MegaDownloadTaskInfo? {
        activeTasks[id]
    }

    /// Devuelve true si se debe emitir progreso y actualiza el último porcentaje reportado
    func shouldEmitProgress(for id: Int, percent: Int, progress: Double) -> Bool {
        let last = lastReportedProgressPercent[id] ?? -1
        let should = percent >= last + 2 || percent == 0 || progress >= 0.99
        if should {
            lastReportedProgressPercent[id] = percent
        }
        return should
    }
}

/// Session de descarga con progreso. Implementa URLSessionDownloadDelegate.
final class MegaDownloadSession: NSObject, URLSessionDownloadDelegate, Sendable {

    private let eventBus: EventBusProtocol
    private let state = MegaDownloadState()
    // nonisolated(unsafe): session se inicializa en init() y nunca se reemplaza
    nonisolated(unsafe) private var session: URLSession!

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
        let taskID = task.taskIdentifier
        Task { [self] in await self.state.addTask(info, for: taskID) }
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
        let taskID = downloadTask.taskIdentifier

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = min(0.99, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        } else {
            progress = min(0.95, Double(totalBytesWritten) / Double(10 * 1024 * 1024))
        }

        let percent = Int(progress * 100)

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.getTask(for: taskID) else { return }
            guard await self.state.shouldEmitProgress(for: taskID, percent: percent, progress: progress) else { return }
            let songID = info.songID
            await MainActor.run { self.eventBus.emit(.progress(songID: songID, progress: progress)) }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskID = downloadTask.taskIdentifier

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.removeTask(for: taskID) else { return }

            let encryptedData: Data
            do {
                encryptedData = try Data(contentsOf: location)
            } catch {
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
                info.continuation.resume(throwing: error)
                return
            }

            do {
                let localURL = try await info.decryptAndSave(encryptedData)
                info.continuation.resume(returning: localURL)
            } catch {
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
                info.continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskIdentifier

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.removeTask(for: taskID) else { return }
            await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
            info.continuation.resume(throwing: error)
        }
    }
}
