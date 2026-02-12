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

/// Handler para desencriptar y guardar un archivo descargado.
/// @MainActor + @Sendable: se ejecuta siempre en el MainActor y es seguro cruzar actores.
typealias MegaDecryptAndSaveHandler = @MainActor @Sendable (Data) async throws -> URL

/// Información de una descarga en curso
struct MegaDownloadTaskInfo: Sendable {
    let songID: UUID
    let file: MegaFile
    let continuation: CheckedContinuation<URL, Error>
    let decryptAndSave: MegaDecryptAndSaveHandler
}

/// Intervalo mínimo entre emisiones de progreso (actualizaciones suaves tipo Spotify)
private let kProgressEmitInterval: TimeInterval = 0.06
/// Avance mínimo para emitir (evita saturar si el throttle por tiempo ya emite)
private let kProgressEmitStep: Double = 0.005

/// Clave única por tarea (evita que al reutilizar taskIdentifier se borre el estado de otra descarga)
private struct TaskKey: Hashable {
    let id: ObjectIdentifier
    init(_ task: URLSessionTask) { id = ObjectIdentifier(task) }
}

/// Estado mutable de las descargas activas — aislado en un actor para Swift 6
private actor MegaDownloadState {
    var activeTasks: [TaskKey: MegaDownloadTaskInfo] = [:]
    var lastEmitProgress: [TaskKey: Double] = [:]
    var lastEmitTime: [TaskKey: Date] = [:]

    func addTask(_ info: MegaDownloadTaskInfo, for key: TaskKey) {
        activeTasks[key] = info
        lastEmitProgress[key] = nil
        lastEmitTime[key] = nil
    }

    func removeTask(for key: TaskKey) -> MegaDownloadTaskInfo? {
        lastEmitProgress.removeValue(forKey: key)
        lastEmitTime.removeValue(forKey: key)
        return activeTasks.removeValue(forKey: key)
    }

    func getTask(for key: TaskKey) -> MegaDownloadTaskInfo? {
        activeTasks[key]
    }

    /// Emitir si pasó el intervalo mínimo o el progreso subió un poco (barra fluida, estilo Spotify).
    func shouldEmitProgress(for key: TaskKey, progress: Double, now: Date) -> Bool {
        let lastP = lastEmitProgress[key] ?? -0.01
        let lastT = lastEmitTime[key] ?? .distantPast
        let timeOk = now.timeIntervalSince(lastT) >= kProgressEmitInterval
        let stepOk = progress >= lastP + kProgressEmitStep
        let should = progress == 0 || progress >= 0.99 || stepOk || timeOk
        if should {
            lastEmitProgress[key] = progress
            lastEmitTime[key] = now
        }
        return should
    }
}

/// Identificador de la sesión de fondo (mismo ID para reconectar tras cierre de app)
private let kMegaBackgroundSessionIdentifier = "com.sinkmusic.mega.downloads"

/// Session de descarga con progreso. Usa configuración background para que las descargas
/// continúen cuando la pantalla se apaga o la app va a segundo plano.
final class MegaDownloadSession: NSObject, URLSessionDownloadDelegate, URLSessionDelegate {

    private let eventBus: EventBusProtocol
    /// Solo se usa desde urlSessionDidFinishEvents → Task { @MainActor in completionService.completeBackgroundSession() }.
    nonisolated(unsafe) private let completionService: BackgroundSessionCompletionServiceProtocol?
    private let state = MegaDownloadState()
    /// Requerido en Swift 6: URLSession no es Sendable y los callbacks del delegate son nonisolated.
    /// La sesión se usa solo en init/startDownload/invalidate; los delegates reciben la sesión por parámetro.
    nonisolated(unsafe) private var session: URLSession!

    init(eventBus: EventBusProtocol, completionService: BackgroundSessionCompletionServiceProtocol?) {
        self.eventBus = eventBus
        self.completionService = completionService
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: kMegaBackgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 600
        config.isDiscretionary = false
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }

    /// Inicia una descarga. El progreso se emite por EventBus. Al terminar se llama decryptAndSave con los datos.
    func startDownload(
        url: URL,
        songID: UUID,
        file: MegaFile,
        continuation: CheckedContinuation<URL, Error>,
        decryptAndSave: @escaping MegaDecryptAndSaveHandler
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
        let key = TaskKey(task)
        Task { [self] in await self.state.addTask(info, for: key) }
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
        let key = TaskKey(downloadTask)

        // 0–99% = descarga real; 100% solo al terminar desencriptado y guardado (progreso continuo y honesto)
        let rawProgress: Double
        if totalBytesExpectedToWrite > 0 {
            rawProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            rawProgress = Double(totalBytesWritten) / Double(10 * 1024 * 1024)
        }
        let progress = min(0.99, rawProgress)

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.getTask(for: key) else { return }
            guard await self.state.shouldEmitProgress(for: key, progress: progress, now: Date()) else { return }
            let songID = info.songID
            await MainActor.run { self.eventBus.emit(.progress(songID: songID, progress: progress)) }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let key = TaskKey(downloadTask)
        // Leer el archivo aquí de forma síncrona: el temp file solo existe durante este callback.
        // Si lo leemos dentro del Task, el callback ya habrá retornado y el sistema puede haber borrado el archivo.
        let dataResult = Result { try Data(contentsOf: location) }

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.removeTask(for: key) else { return }

            let encryptedData: Data
            switch dataResult {
            case .success(let data):
                encryptedData = data
            case .failure(let error):
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
                info.continuation.resume(throwing: error)
                return
            }

            // Pequeño avance al iniciar desencriptado (evita sensación de congelado en 99%)
            await MainActor.run { self.eventBus.emit(.progress(songID: info.songID, progress: 0.995)) }
            do {
                let localURL = try await info.decryptAndSave(encryptedData)
                await MainActor.run { self.eventBus.emit(.progress(songID: info.songID, progress: 1.0)) }
                info.continuation.resume(returning: localURL)
            } catch {
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
                info.continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let key = TaskKey(task)

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.removeTask(for: key) else { return }
            await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, error: error.localizedDescription)) }
            info.continuation.resume(throwing: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let completionService else { return }
        Task { @MainActor in
            completionService.completeBackgroundSession()
        }
    }
}
