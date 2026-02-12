//
//  DownloadViewModel.swift
//  sinkmusic
//
//  Created by Clean Architecture Refactor
//  REEMPLAZO de SongListViewModel legacy
//

import Foundation

/// Gestor de tareas de descarga activas para cancelación
private final class ActiveTasksManager {
    var tasks: [UUID: Task<Void, Never>] = [:]
}

/// ViewModel responsable de gestionar descargas de canciones
/// Cumple con Clean Architecture - Solo depende de UseCases
/// Usa EventBus con AsyncStream para reactividad moderna
/// Soporta descargas paralelas limitadas por proveedor
@MainActor
@Observable
final class DownloadViewModel {

    // MARK: - Published State

    /// Progreso de descarga por canción (UUID -> 0.0...1.0)
    var downloadProgress: [UUID: Double] = [:]

    /// Error de descarga (si existe)
    var downloadError: String? = nil

    /// Indicador si hay una descarga en progreso
    var isDownloading: Bool = false

    // MARK: - Quota State

    /// Proveedor que alcanzó el límite de cuota
    var quotaExceededProvider: CloudStorageProvider?

    /// Tiempo hasta que se pueda reintentar
    var quotaResetTime: Date?

    /// Mostrar alerta de cuota excedida
    var showQuotaAlert: Bool = false

    // MARK: - Dependencies

    private let downloadUseCases: DownloadUseCases
    private let eventBus: EventBusProtocol
    private let credentialsRepository: CredentialsRepositoryProtocol

    // MARK: - Queue Manager

    /// Gestor de cola de descargas con límites por proveedor
    private let queueManager = DownloadQueueManager()

    // MARK: - Private State

    /// Gestor de tareas de descarga activas para cancelación
    private let activeTasksManager = ActiveTasksManager()

    /// Task para observación de eventos de descarga
    @ObservationIgnored
    private var downloadEventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(downloadUseCases: DownloadUseCases, eventBus: EventBusProtocol, credentialsRepository: CredentialsRepositoryProtocol) {
        self.downloadUseCases = downloadUseCases
        self.eventBus = eventBus
        self.credentialsRepository = credentialsRepository
        startObservingEvents()
    }

    // MARK: - Event Observation (EventBus + AsyncStream)

    private func startObservingEvents() {
        downloadEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.eventBus.downloadEvents() {
                guard !Task.isCancelled else { break }
                await self.handleDownloadEvent(event)
            }
        }
    }

    private func handleDownloadEvent(_ event: DownloadEvent) async {
        switch event {
        case .started(let songID):
            // Solo actualizar si nosotros iniciamos esta descarga
            if activeTasksManager.tasks[songID] != nil {
                downloadProgress[songID] = 0.0
            }

        case .progress(let songID, let progress):
            // Solo actualizar si nosotros iniciamos esta descarga
            if activeTasksManager.tasks[songID] != nil {
                downloadProgress[songID] = progress
            }

        case .completed(let songID):
            // Solo actualizar si nosotros iniciamos esta descarga
            if activeTasksManager.tasks[songID] != nil {
                downloadProgress[songID] = 1.0
                print("✅ Descarga completada (via EventBus): \(songID)")

                // Mantener barra en 100% por 0.5 segundos para feedback visual
                try? await Task.sleep(nanoseconds: 500_000_000)

                // Limpiar progreso y tarea (liberar memoria por canción).
                // Misma ruta con pantalla activa o en background: el evento llega al reabrir si terminó en segundo plano.
                downloadProgress[songID] = nil
                activeTasksManager.tasks.removeValue(forKey: songID)
                isDownloading = !activeTasksManager.tasks.isEmpty
                // Cuando no quede ninguna tarea, dejar estado limpio
                if !isDownloading { downloadError = nil }
            }

        case .failed(let songID, let error):
            // Solo actualizar si nosotros iniciamos esta descarga
            if activeTasksManager.tasks[songID] != nil {
                downloadProgress[songID] = nil
                downloadError = "Error descargando canción: \(error)"
                print("❌ Error descarga (via EventBus): \(error)")

                // Limpiar tarea
                activeTasksManager.tasks.removeValue(forKey: songID)
                isDownloading = !activeTasksManager.tasks.isEmpty
                if !isDownloading { downloadError = nil }
            }

        case .cancelled(let songID):
            // Solo actualizar si nosotros iniciamos esta descarga
            if activeTasksManager.tasks[songID] != nil {
                downloadProgress[songID] = nil
                activeTasksManager.tasks.removeValue(forKey: songID)
                isDownloading = !activeTasksManager.tasks.isEmpty
                print("⏸️ Descarga cancelada (via EventBus): \(songID)")
            }

        case .queued(let songID, let position):
            print("📋 Canción en cola (posición \(position)): \(songID)")

        case .quotaExceeded(let provider, let resetTime):
            quotaExceededProvider = CloudStorageProvider(rawValue: provider)
            quotaResetTime = resetTime
            showQuotaAlert = true
            print("⚠️ Cuota excedida para \(provider). Reset: \(resetTime)")
        }
    }

    // MARK: - Download Operations

    /// Descarga una canción por su ID
    /// El progreso y completado se reciben via EventBus
    /// Usa cola con límites por proveedor (Google Drive: 1, Mega: 3)
    /// - Parameter songID: ID de la canción a descargar
    func download(songID: UUID) async {
        // Evitar descargas duplicadas
        guard activeTasksManager.tasks[songID] == nil else {
            print("⏭️ Descarga ya en progreso para \(songID)")
            return
        }

        // Obtener proveedor actual
        let provider = credentialsRepository.getSelectedCloudProvider()

        // Verificar si la cuota está excedida
        if let resetTime = await queueManager.getQuotaResetTime(for: provider) {
            quotaExceededProvider = provider
            quotaResetTime = resetTime
            showQuotaAlert = true
            print("⚠️ Cuota aún excedida para \(provider.rawValue). Esperar hasta \(resetTime)")
            return
        }

        // Crear tarea de descarga (weak self para evitar ciclo de retención)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            // Iniciar progreso en 0%
            downloadProgress[songID] = 0.0
            isDownloading = true
            downloadError = nil

            print("📥 Solicitando slot de descarga: \(songID)")

            // Solicitar slot de descarga (espera si la cola está llena)
            let gotSlot = await queueManager.requestDownloadSlot(for: songID, provider: provider)

            guard gotSlot else {
                // Cuota excedida mientras esperaba en cola
                downloadProgress[songID] = nil
                activeTasksManager.tasks.removeValue(forKey: songID)
                isDownloading = !activeTasksManager.tasks.isEmpty

                if let resetTime = await queueManager.getQuotaResetTime(for: provider) {
                    quotaExceededProvider = provider
                    quotaResetTime = resetTime
                    showQuotaAlert = true
                }
                return
            }

            defer {
                // Liberar slot al terminar (éxito o error) para liberar memoria de cola
                Task { [weak self] in
                    guard let self else { return }
                    await self.queueManager.releaseDownloadSlot(for: provider)
                }
            }

            print("📥 Iniciando descarga: \(songID)")

            do {
                // Descargar usando UseCases
                // El progreso y completado se emiten via EventBus y se manejan en handleDownloadEvent
                try await downloadUseCases.downloadSong(songID)

                // Nota: La limpieza de estado se hace en handleDownloadEvent(.completed)

            } catch let megaError as MegaError where megaError.isRateLimitError {
                // Manejar límite de cuota de Mega: terminar proceso y liberar toda la memoria
                let retryAfter = megaError.retryAfterSeconds ?? 3600

                await queueManager.markQuotaExceeded(provider: provider, retryAfter: retryAfter)

                quotaExceededProvider = provider
                quotaResetTime = Date().addingTimeInterval(retryAfter)
                showQuotaAlert = true
                downloadError = megaError.localizedDescription

                eventBus.emit(DownloadEvent.quotaExceeded(
                    provider: provider.rawValue,
                    resetTime: Date().addingTimeInterval(retryAfter)
                ))

                // Borrar todo lo que esté en memoria: cancelar todas las descargas y vaciar progreso
                clearAllTasksAndProgress()
                print("⚠️ Límite Mega alcanzado; descargas canceladas y estado limpiado")

            } catch {
                // Nota: El error también se emite via EventBus
                // Este catch es para errores que ocurren ANTES de iniciar la descarga
                // (como songNotFound, alreadyDownloaded)
                downloadProgress[songID] = nil
                downloadError = "Error descargando canción: \(error.localizedDescription)"
                print("❌ \(downloadError!)")

                // Limpiar tarea
                activeTasksManager.tasks.removeValue(forKey: songID)
                isDownloading = !activeTasksManager.tasks.isEmpty
            }
        }

        // Guardar tarea y esperar a que termine (así "Descargar todo" es realmente secuencial)
        activeTasksManager.tasks[songID] = task
        await task.value
    }

    /// Descarga múltiples canciones en cola secuencial (una tras otra).
    /// Cada petición pasa por el actor DownloadQueueManager (Swift 6); con Mega pueden
    /// coexistir hasta 3 descargas si se lanzan por otros medios, pero aquí es secuencial.
    /// Al terminar todo el proceso se deja el estado limpio (sin retenciones).
    /// - Parameter songIDs: IDs de las canciones a descargar
    func downloadMultiple(songIDs: [UUID]) async {
        for songID in songIDs {
            await download(songID: songID)
        }
        // Limpieza explícita al terminar todo: sin ciclos de retención ni estado residual
        cleanupWhenIdle()
    }

    /// Elimina la descarga de una canción
    /// - Parameter songID: ID de la canción
    func deleteDownload(songID: UUID) async {
        do {
            // Cancelar descarga si está en progreso
            if let task = activeTasksManager.tasks[songID] {
                task.cancel()
                activeTasksManager.tasks.removeValue(forKey: songID)
                downloadProgress.removeValue(forKey: songID)
            }

            // Eliminar descarga usando UseCases
            try await downloadUseCases.deleteDownload(songID)

            // Limpiar error si existía
            downloadError = nil
            print("🗑️ Descarga eliminada: \(songID)")

        } catch {
            downloadError = "Error eliminando descarga: \(error.localizedDescription)"
            print("❌ \(downloadError!)")
        }

        // Actualizar flag de descarga
        isDownloading = !activeTasksManager.tasks.isEmpty
    }

    /// Cancela una descarga en progreso
    /// - Parameter songID: ID de la canción
    func cancelDownload(songID: UUID) {
        guard let task = activeTasksManager.tasks[songID] else { return }

        task.cancel()
        activeTasksManager.tasks.removeValue(forKey: songID)
        downloadProgress.removeValue(forKey: songID)

        // Actualizar flag de descarga
        isDownloading = !activeTasksManager.tasks.isEmpty

        print("⏸️ Descarga cancelada: \(songID)")
    }

    /// Cancela todas las descargas en progreso
    func cancelAllDownloads() {
        for (songID, task) in activeTasksManager.tasks {
            task.cancel()
            downloadProgress.removeValue(forKey: songID)
            print("⏸️ Descarga cancelada: \(songID)")
        }

        activeTasksManager.tasks.removeAll()
        downloadProgress.removeAll()
        downloadError = nil
        isDownloading = false

        // Resetear cola (liberar continuations pendientes)
        Task { [weak self] in
            guard let self else { return }
            await self.queueManager.reset()
        }
    }

    /// Deja el estado limpio cuando no hay descargas activas (evita retenciones residuales).
    private func cleanupWhenIdle() {
        guard activeTasksManager.tasks.isEmpty else { return }
        isDownloading = false
        downloadError = nil
        // downloadProgress ya está vacío por cada .completed/.failed; por si acaso no quedar claves huérfanas
        downloadProgress.removeAll()
    }

    /// Cancela todas las tareas de descarga y vacía el progreso (libera memoria).
    /// Se usa cuando se alcanza el límite de Mega para que no quede nada ocupando memoria.
    private func clearAllTasksAndProgress() {
        for (_, task) in activeTasksManager.tasks {
            task.cancel()
        }
        activeTasksManager.tasks.removeAll()
        downloadProgress.removeAll()
        isDownloading = false
    }

    // MARK: - Quota Management

    /// Limpia la alerta de cuota
    func dismissQuotaAlert() {
        showQuotaAlert = false
    }

    /// Tiempo restante formateado hasta poder reintentar
    var quotaResetTimeFormatted: String? {
        guard let resetTime = quotaResetTime else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: resetTime, relativeTo: Date())
    }

    // MARK: - Error Handling

    /// Limpia el error de descarga
    func clearDownloadError() {
        downloadError = nil
    }

    // MARK: - Utilities

    /// True si el proveedor actual es Mega (permite descarga masiva)
    var isMegaProvider: Bool {
        credentialsRepository.getSelectedCloudProvider() == .mega
    }

    /// True si Mega tiene el límite de cuota alcanzado (informar al usuario)
    var isMegaQuotaExceeded: Bool {
        quotaExceededProvider == .mega
    }

    /// Verifica si una canción está siendo descargada
    /// - Parameter songID: ID de la canción
    /// - Returns: true si está en progreso
    func isDownloading(songID: UUID) -> Bool {
        return activeTasksManager.tasks[songID] != nil
    }

    /// Obtiene el progreso de una canción específica
    /// - Parameter songID: ID de la canción
    /// - Returns: Progreso (0.0...1.0) o nil si no está descargando
    func progress(for songID: UUID) -> Double? {
        return downloadProgress[songID]
    }

}
