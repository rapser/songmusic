//
//  MegaDataSource.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation
import AVFoundation

/// DataSource para acceder a archivos de Mega
/// Implementa listado de carpetas públicas, descarga y desencriptación
@MainActor
final class MegaDataSource: NSObject, MegaServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol
    private let crypto: MegaCrypto

    // MARK: - Constants

    private let megaAPIURL = "https://g.api.mega.co.nz/cs"
    private let musicDirectory: URL

    // MARK: - Download State

    /// Handle de la carpeta pública para requests de descarga
    private var publicFolderHandle: String?

    /// Session y estado para descarga con progreso (accesibles desde delegate y deinit en contexto nonisolated)
    private let megaDownloadsLock = NSLock()
    private nonisolated(unsafe) var megaActiveDownloads: [Int: (songID: UUID, continuation: CheckedContinuation<URL, Error>, file: MegaFile)] = [:]
    private nonisolated(unsafe) var megaLastReportedProgress: [Int: Int] = [:]
    private nonisolated(unsafe) var megaDownloadSession: URLSession!

    // MARK: - Initialization

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
        self.crypto = MegaCrypto()

        // Configurar directorio de música
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.musicDirectory = documentsDirectory.appendingPathComponent("Music")

        super.init()

        // Crear directorio si no existe
        try? FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)

        // Session de descarga (delegate: self, accesible desde nonisolated deinit)
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 600
        megaDownloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Fetch Files

    func fetchFilesFromFolder(folderURL: String) async throws -> [MegaFile] {
        // 1. Parsear URL para obtener nodeId y clave
        let (nodeId, folderKey) = try crypto.parseFolderURL(folderURL)
        
        // Guardar el nodeId de la carpeta pública para usar en descargas
        publicFolderHandle = nodeId

        // 2. Llamar API de Mega para obtener contenido de la carpeta (recursivo con r=1)
        let response = try await fetchFolderContents(nodeId: nodeId)

        // 3. Procesar nodos
        var files: [MegaFile] = []

        guard let nodes = response.f else {
            print("⚠️ No se encontraron nodos en la respuesta de Mega")
            return files
        }

        print("📁 Total de nodos recibidos de Mega: \(nodes.count)")

        // Contar tipos de nodos para debug
        let fileNodes = nodes.filter { $0.t == 0 }
        let folderNodes = nodes.filter { $0.t == 1 || $0.t == 2 }
        print("📁 Carpetas: \(folderNodes.count), Archivos: \(fileNodes.count)")

        // Procesar TODOS los archivos (type = 0), sin importar su ubicación
        // La API de Mega con r=1 ya devuelve todos los archivos recursivamente
        for node in nodes {
            // Solo procesar archivos (type = 0)
            guard node.t == 0,
                  let encryptedAttrs = node.a,
                  let keyString = node.k else {
                continue
            }

            // La clave del archivo se deriva de la clave de la carpeta compartida (raíz)
            // En carpetas públicas de Mega, todas las claves se derivan de la clave raíz
            guard let fileKey = crypto.parseNodeKey(keyString, folderKey: folderKey) else {
                print("⚠️ No se pudo derivar clave para nodo: \(node.h)")
                continue
            }

            // Desencriptar atributos (nombre del archivo)
            guard let attrs = crypto.decryptAttributes(encryptedAttrs, key: fileKey),
                  let fileName = attrs["n"] as? String else {
                print("⚠️ No se pudo desencriptar atributos para nodo: \(node.h)")
                continue
            }

            // Filtrar solo archivos de audio
            let lowercaseName = fileName.lowercased()
            guard lowercaseName.hasSuffix(".m4a") ||
                  lowercaseName.hasSuffix(".mp3") ||
                  lowercaseName.hasSuffix(".mp4") ||
                  lowercaseName.hasSuffix(".aac") ||
                  lowercaseName.hasSuffix(".flac") ||
                  lowercaseName.hasSuffix(".wav") ||
                  lowercaseName.hasSuffix(".ogg") else {
                continue
            }

            // Crear MegaFile
            let file = MegaFile(
                id: node.h,
                name: fileName,
                size: node.s,
                decryptionKey: fileKey.base64EncodedString(),
                parentId: node.p
            )

            files.append(file)
        }

        print("🎵 Archivos de audio encontrados: \(files.count)")

        // Ordenar por nombre
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return files
    }

    /// Llama a la API de Mega para obtener el contenido de una carpeta
    private func fetchFolderContents(nodeId: String) async throws -> MegaFolderResponse {
        guard let url = URL(string: "\(megaAPIURL)?id=\(Int.random(in: 0..<Int.max))&n=\(nodeId)") else {
            throw MegaError.invalidFolderURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Request para obtener contenido de carpeta pública
        let requestBody: [[String: Any]] = [
            ["a": "f", "c": 1, "r": 1, "ca": 1]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MegaError.apiError("Respuesta inválida")
        }

        // Verificar rate limiting
        if httpResponse.statusCode == 509 {
            let retryAfter = parseRetryAfterHeader(httpResponse)
            throw MegaError.rateLimitExceeded(retryAfter: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            throw MegaError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // La respuesta es un array, tomamos el primer elemento
        guard let responseArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstResponse = responseArray.first else {
            // Si es un número negativo, es un código de error
            if let errorCode = try? JSONSerialization.jsonObject(with: data) as? Int, errorCode < 0 {
                throw MegaError.apiError("Código de error: \(errorCode)")
            }
            throw MegaError.apiError("Respuesta vacía")
        }

        // Decodificar respuesta
        let responseData = try JSONSerialization.data(withJSONObject: firstResponse)
        let folderResponse = try JSONDecoder().decode(MegaFolderResponse.self, from: responseData)

        return folderResponse
    }

    // MARK: - Download

    func download(file: MegaFile, songID: UUID) async throws -> URL {
        eventBus.emit(.started(songID: songID))

        do {
            print("📥 Descargando archivo de Mega:")
            print("   Archivo: \(file.name)")
            print("   FileID: \(file.id)")
            print("   Handle público (raíz): \(publicFolderHandle ?? "ninguno")")

            let downloadURL = try await getDownloadURL(for: file.id, folderHandle: publicFolderHandle)

            return try await withCheckedThrowingContinuation { continuation in
                var request = URLRequest(url: downloadURL)
                request.timeoutInterval = 600
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let task = megaDownloadSession.downloadTask(with: request)
                megaDownloadsLock.lock()
                megaActiveDownloads[task.taskIdentifier] = (songID: songID, continuation: continuation, file: file)
                megaDownloadsLock.unlock()
                task.resume()
            }
        } catch {
            eventBus.emit(.failed(songID: songID, error: error.localizedDescription))
            throw error
        }
    }

    /// Obtiene la URL de descarga temporal de Mega
    private func getDownloadURL(for fileId: String, folderHandle: String?) async throws -> URL {
        print("🌐 Solicitando URL de descarga a Mega para fileID: \(fileId)")
        
        // Para carpetas públicas, necesitamos incluir el handle de la carpeta donde está el archivo
        var urlString = "\(megaAPIURL)?id=\(Int.random(in: 0..<Int.max))"
        if let handle = folderHandle {
            urlString += "&n=\(handle)"
            print("   📁 Usando handle de carpeta: \(handle)")
        } else {
            print("   ⚠️ No se proporcionó handle de carpeta")
        }
        
        guard let url = URL(string: urlString) else {
            throw MegaError.invalidFolderURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Request para obtener URL de descarga
        let requestBody: [[String: Any]] = [
            ["a": "g", "g": 1, "n": fileId]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Log del request para debugging
        if let requestBodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request a Mega API:")
            print("   URL: \(url)")
            print("   Body: \(requestBodyString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Log de la respuesta para debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Respuesta de Mega API:")
            print("   \(responseString.prefix(500))") // Primeros 500 caracteres
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MegaError.apiError("Respuesta inválida")
        }

        if httpResponse.statusCode == 509 {
            let retryAfter = parseRetryAfterHeader(httpResponse)
            throw MegaError.rateLimitExceeded(retryAfter: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            throw MegaError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parsear respuesta
        guard let responseArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstResponse = responseArray.first,
              let downloadURLString = firstResponse["g"] as? String else {

            // Verificar si es un código de error
            if let responseArray = try? JSONSerialization.jsonObject(with: data) as? [Int],
               let errorCode = responseArray.first, errorCode < 0 {

                print("❌ API de Mega devolvió código de error: \(errorCode)")
                print("   FileID solicitado: \(fileId)")
                print("   Handle usado: \(folderHandle ?? "ninguno")")

                switch errorCode {
                case -9:
                    print("   ⚠️ Error -9: Object not found")
                    print("   Esto puede indicar que:")
                    print("   1. El archivo fue eliminado o movido")
                    print("   2. El fileID no es correcto")
                    print("   3. No tienes permisos para acceder al archivo")
                    throw MegaError.fileNotFound
                case -18:
                    // Rate limit (código -18) - usar 1 hora por defecto
                    throw MegaError.rateLimitExceeded(retryAfter: 3600)
                default:
                    throw MegaError.apiError("Código de error: \(errorCode)")
                }
            }

            // Log de respuesta inesperada
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Respuesta inesperada de Mega API:")
                print("   FileID: \(fileId)")
                print("   Handle: \(folderHandle ?? "ninguno")")
                print("   Respuesta: \(responseString)")
            }

            throw MegaError.apiError("No se pudo obtener URL de descarga")
        }
        
        // Nota: Mega usa HTTP porque los archivos ya están encriptados (E2EE)
        // No convertimos a HTTPS porque algunos servidores solo soportan HTTP
        // y es más rápido (menor overhead). La seguridad está en la encriptación.
        
        guard let downloadURL = URL(string: downloadURLString) else {
            throw MegaError.apiError("URL de descarga inválida")
        }

        print("✅ URL de descarga obtenida: \(downloadURL.scheme ?? "unknown")://...")
        return downloadURL
    }

    // MARK: - Local File Management

    func localURL(for songID: UUID) -> URL? {
        let fileURL = musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func getDuration(for url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = audioFile.length
            return Double(frameCount) / format.sampleRate
        } catch {
            print("❌ Error al obtener duración: \(error)")
            return nil
        }
    }

    func deleteDownload(for songID: UUID) throws {
        let fileURL = musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Rate Limit Helpers

    /// Parsea el header Retry-After de la respuesta HTTP
    /// - Parameter response: Respuesta HTTP
    /// - Returns: Tiempo en segundos para reintentar (default: 3600 = 1 hora)
    private func parseRetryAfterHeader(_ response: HTTPURLResponse) -> TimeInterval {
        // Intentar leer Retry-After como segundos
        if let retryAfterString = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfterString) {
            return seconds
        }

        // Mega generalmente usa 1 hora para cuentas gratuitas
        return 3600
    }

    // MARK: - Cleanup

    deinit {
        megaDownloadSession?.invalidateAndCancel()
    }
}

// MARK: - URLSessionDownloadDelegate

extension MegaDataSource: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        megaDownloadsLock.lock()
        guard let info = megaActiveDownloads[downloadTask.taskIdentifier] else {
            megaDownloadsLock.unlock()
            return
        }
        let songID = info.songID
        megaDownloadsLock.unlock()

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = min(0.99, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        } else {
            let estimated: Int64 = 10 * 1024 * 1024
            progress = min(0.95, Double(totalBytesWritten) / Double(estimated))
        }

        let progressPercent = Int(progress * 100)
        megaDownloadsLock.lock()
        let last = megaLastReportedProgress[downloadTask.taskIdentifier] ?? -1
        // Emitir cada 2% para que la barra se vea moverse, o al llegar al final
        let shouldEmit = progressPercent >= last + 2 || progressPercent == 0 || progress >= 0.99
        if shouldEmit {
            megaLastReportedProgress[downloadTask.taskIdentifier] = progressPercent
        }
        megaDownloadsLock.unlock()

        if shouldEmit {
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.progress(songID: songID, progress: progress))
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        megaDownloadsLock.lock()
        guard let info = megaActiveDownloads.removeValue(forKey: downloadTask.taskIdentifier) else {
            megaDownloadsLock.unlock()
            return
        }
        megaLastReportedProgress.removeValue(forKey: downloadTask.taskIdentifier)
        megaDownloadsLock.unlock()

        let songID = info.songID
        let file = info.file
        let continuation = info.continuation

        // Leer el archivo temporal AHORA (síncronamente). URLSession borra el archivo
        // al salir de este callback, por eso no podemos leerlo dentro de un Task async.
        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: location)
        } catch {
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.failed(songID: songID, error: error.localizedDescription))
            }
            continuation.resume(throwing: error)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                continuation.resume(throwing: MegaError.downloadFailed("DataSource no disponible"))
                return
            }
            do {
                guard let keyData = Data(base64Encoded: file.decryptionKey),
                      let decryptedData = self.crypto.decryptFile(encryptedData: encryptedData, fileKey: keyData) else {
                    continuation.resume(throwing: MegaError.decryptionFailed)
                    return
                }
                let localURL = self.musicDirectory.appendingPathComponent("\(songID.uuidString).m4a")
                try decryptedData.write(to: localURL)
                self.eventBus.emit(.completed(songID: songID))
                continuation.resume(returning: localURL)
            } catch {
                self.eventBus.emit(.failed(songID: songID, error: error.localizedDescription))
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        megaDownloadsLock.lock()
        guard let info = megaActiveDownloads.removeValue(forKey: task.taskIdentifier) else {
            megaDownloadsLock.unlock()
            return
        }
        megaLastReportedProgress.removeValue(forKey: task.taskIdentifier)
        megaDownloadsLock.unlock()

        let songID = info.songID
        let continuation = info.continuation
        Task { @MainActor [weak self] in
            self?.eventBus.emit(.failed(songID: songID, error: error.localizedDescription))
        }
        continuation.resume(throwing: error)
    }
}
