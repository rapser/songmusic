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
/// Recibe la URL del archivo **cifrado ya movido a staging** (no los bytes en RAM) y devuelve
/// la URL del archivo descifrado final. `@Sendable`: el desencriptado corre fuera del MainActor.
typealias MegaDecryptAndSaveHandler = @Sendable (URL) async throws -> URL

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
        // Sesión background: la transferencia continúa si la app pasa a segundo plano.
        // El coste es que el SO la programa a su ritmo (no está optimizada para latencia).
        let config = URLSessionConfiguration.background(withIdentifier: kMegaBackgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        // 120 s (antes 600): un socket medio-abierto se revela como error en 2 min, no en 10.
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 3600
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
        request.timeoutInterval = 120
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

        // 0–90% = descarga de red. El resto del pipeline (desencriptado, metadata,
        // guardado en SwiftData) completa el 90–100% — ver DownloadUseCases.downloadSong.
        let rawProgress: Double
        if totalBytesExpectedToWrite > 0 {
            rawProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            rawProgress = Double(totalBytesWritten) / Double(10 * 1024 * 1024)
        }
        let progress = min(0.90, rawProgress * 0.90)

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
        // El temp file solo existe durante este callback: hay que sacarlo de aquí YA.
        // Se mueve a staging (mover en el mismo volumen es O(1)); si el move fallara
        // (volumen distinto), se cae a copiar vía RAM como antes. No se lee a `Data` en
        // el caso normal — el desencriptado luego lee en streaming desde staging.
        let stagedResult: Result<URL, Error> = Result {
            let fm = FileManager.default
            let dir = fm.temporaryDirectory.appendingPathComponent("mega-staging", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let staged = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("enc")
            do {
                try fm.moveItem(at: location, to: staged)
            } catch {
                try Data(contentsOf: location).write(to: staged, options: .atomic)
            }
            return staged
        }

        Task { [weak self] in
            guard let self else { return }
            guard let info = await self.state.removeTask(for: key) else {
                if case .success(let staged) = stagedResult { try? FileManager.default.removeItem(at: staged) }
                return
            }

            let encryptedURL: URL
            switch stagedResult {
            case .success(let url):
                encryptedURL = url
            case .failure(let error):
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, failure: DownloadFailure(error: error))) }
                info.continuation.resume(throwing: error)
                return
            }

            // Fase de desencriptado (la red terminó en 90%)
            await MainActor.run { self.eventBus.emit(.progress(songID: info.songID, progress: 0.92)) }
            do {
                let localURL = try await info.decryptAndSave(encryptedURL)
                // Archivo en disco; faltan metadata y guardado en SwiftData (DownloadUseCases)
                await MainActor.run { self.eventBus.emit(.progress(songID: info.songID, progress: 0.95)) }
                info.continuation.resume(returning: localURL)
            } catch {
                try? FileManager.default.removeItem(at: encryptedURL)
                await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, failure: DownloadFailure(error: error))) }
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
            await MainActor.run { self.eventBus.emit(.failed(songID: info.songID, failure: DownloadFailure(error: error))) }
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
