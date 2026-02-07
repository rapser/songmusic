//
//  DownloadQueueManager.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Actor que gestiona la cola de descargas con límites por proveedor
/// Google Drive: 1 descarga concurrente (se bloquea fácilmente)
/// Mega: 3 descargas concurrentes (más permisivo)
actor DownloadQueueManager {

    // MARK: - Configuration

    /// Límites de descargas concurrentes por proveedor
    private let maxConcurrent: [CloudStorageProvider: Int] = [
        .googleDrive: 1,  // Secuencial (se bloquea fácilmente)
        .mega: 3          // Paralelo (más permisivo)
    ]

    // MARK: - State

    /// Conteo de descargas activas por proveedor
    private var activeDownloads: [CloudStorageProvider: Int] = [
        .googleDrive: 0,
        .mega: 0
    ]

    /// Cola de descargas pendientes esperando un slot
    private var pendingQueue: [(songID: UUID, provider: CloudStorageProvider, continuation: CheckedContinuation<Void, Never>)] = []

    /// Timestamp hasta cuando la cuota está excedida por proveedor
    private var quotaExceededUntil: [CloudStorageProvider: Date] = [:]

    // MARK: - Download Slot Management

    /// Solicita un slot de descarga. Si no hay slots disponibles, espera en cola.
    /// - Parameters:
    ///   - songID: ID de la canción a descargar
    ///   - provider: Proveedor de almacenamiento cloud
    /// - Returns: true si se obtuvo el slot, false si la cuota está excedida
    func requestDownloadSlot(for songID: UUID, provider: CloudStorageProvider) async -> Bool {
        // Verificar si la cuota está excedida
        if let resetTime = quotaExceededUntil[provider], Date() < resetTime {
            // Aún en período de espera por cuota excedida
            return false
        }

        // Limpiar cuota si ya pasó el tiempo
        quotaExceededUntil[provider] = nil

        let currentActive = activeDownloads[provider] ?? 0
        let limit = maxConcurrent[provider] ?? 1

        if currentActive < limit {
            // Hay espacio disponible, reservar slot inmediatamente
            activeDownloads[provider] = currentActive + 1
            return true
        } else {
            // Cola llena, esperar
            await withCheckedContinuation { continuation in
                pendingQueue.append((songID, provider, continuation))
            }
            return true
        }
    }

    /// Libera un slot de descarga y procesa el siguiente en cola
    /// - Parameter provider: Proveedor de almacenamiento cloud
    func releaseDownloadSlot(for provider: CloudStorageProvider) {
        let current = activeDownloads[provider] ?? 1
        activeDownloads[provider] = max(0, current - 1)

        // Buscar siguiente descarga pendiente del mismo proveedor
        if let index = pendingQueue.firstIndex(where: { $0.provider == provider }) {
            let pending = pendingQueue.remove(at: index)
            activeDownloads[provider] = (activeDownloads[provider] ?? 0) + 1
            pending.continuation.resume()
        }
    }

    // MARK: - Quota Management

    /// Marca un proveedor como limitado por cuota
    /// - Parameters:
    ///   - provider: Proveedor de almacenamiento cloud
    ///   - retryAfter: Segundos hasta que se pueda reintentar (default: 1 hora)
    func markQuotaExceeded(provider: CloudStorageProvider, retryAfter: TimeInterval = 3600) {
        quotaExceededUntil[provider] = Date().addingTimeInterval(retryAfter)

        // Cancelar todas las descargas pendientes de este proveedor
        let pendingForProvider = pendingQueue.filter { $0.provider == provider }
        pendingQueue.removeAll { $0.provider == provider }

        // Liberar las continuations pendientes
        for pending in pendingForProvider {
            pending.continuation.resume()
        }

        print("⚠️ Cuota excedida para \(provider.rawValue). Reintentar en \(Int(retryAfter / 60)) minutos")
    }

    /// Obtiene el tiempo de reset de cuota para un proveedor
    /// - Parameter provider: Proveedor de almacenamiento cloud
    /// - Returns: Fecha de reset si la cuota está excedida, nil si está disponible
    func getQuotaResetTime(for provider: CloudStorageProvider) -> Date? {
        guard let resetTime = quotaExceededUntil[provider], Date() < resetTime else {
            return nil
        }
        return resetTime
    }

    /// Verifica si la cuota está excedida para un proveedor
    /// - Parameter provider: Proveedor de almacenamiento cloud
    /// - Returns: true si la cuota está excedida
    func isQuotaExceeded(for provider: CloudStorageProvider) -> Bool {
        guard let resetTime = quotaExceededUntil[provider] else {
            return false
        }
        return Date() < resetTime
    }

    /// Limpia el estado de cuota excedida manualmente
    /// - Parameter provider: Proveedor de almacenamiento cloud
    func clearQuotaExceeded(for provider: CloudStorageProvider) {
        quotaExceededUntil[provider] = nil
    }

    // MARK: - Queue Info

    /// Obtiene el número de descargas activas para un proveedor
    /// - Parameter provider: Proveedor de almacenamiento cloud
    /// - Returns: Número de descargas activas
    func activeDownloadCount(for provider: CloudStorageProvider) -> Int {
        return activeDownloads[provider] ?? 0
    }

    /// Obtiene el número de descargas en cola para un proveedor
    /// - Parameter provider: Proveedor de almacenamiento cloud
    /// - Returns: Número de descargas en cola
    func pendingDownloadCount(for provider: CloudStorageProvider) -> Int {
        return pendingQueue.filter { $0.provider == provider }.count
    }

    /// Obtiene la posición en cola de una canción
    /// - Parameters:
    ///   - songID: ID de la canción
    ///   - provider: Proveedor de almacenamiento cloud
    /// - Returns: Posición en cola (1-based), nil si no está en cola
    func queuePosition(for songID: UUID, provider: CloudStorageProvider) -> Int? {
        guard let index = pendingQueue.firstIndex(where: { $0.songID == songID && $0.provider == provider }) else {
            return nil
        }
        return index + 1
    }

    /// Cancela una descarga pendiente de la cola
    /// - Parameter songID: ID de la canción a cancelar
    /// - Returns: true si se encontró y canceló, false si no estaba en cola
    @discardableResult
    func cancelPending(songID: UUID) -> Bool {
        guard let index = pendingQueue.firstIndex(where: { $0.songID == songID }) else {
            return false
        }
        let pending = pendingQueue.remove(at: index)
        pending.continuation.resume()
        return true
    }

    /// Cancela todas las descargas pendientes de un proveedor
    /// - Parameter provider: Proveedor de almacenamiento cloud
    func cancelAllPending(for provider: CloudStorageProvider) {
        let pendingForProvider = pendingQueue.filter { $0.provider == provider }
        pendingQueue.removeAll { $0.provider == provider }

        for pending in pendingForProvider {
            pending.continuation.resume()
        }
    }

    /// Reinicia completamente el estado del manager
    func reset() {
        // Liberar todas las continuations pendientes
        for pending in pendingQueue {
            pending.continuation.resume()
        }
        pendingQueue.removeAll()
        activeDownloads = [.googleDrive: 0, .mega: 0]
        quotaExceededUntil.removeAll()
    }
}
