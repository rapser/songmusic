//
//  DownloadViewModel.swift
//  sinkmusic
//
//  Created by Clean Architecture Refactor
//  REEMPLAZO de SongListViewModel legacy
//

import Foundation

/// Gestor de tareas de descarga (no aislado al MainActor para acceso en deinit)
private final class ActiveTasksManager {
    var tasks: [UUID: Task<Void, Never>] = [:]
}

/// ViewModel responsable de gestionar descargas de canciones
/// Cumple con Clean Architecture - Solo depende de UseCases
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

    // MARK: - Dependencies

    private let downloadUseCases: DownloadUseCases

    // MARK: - Private State

    /// Gestor de tareas de descarga activas para cancelación
    private let activeTasksManager = ActiveTasksManager()

    // MARK: - Initialization

    init(downloadUseCases: DownloadUseCases) {
        self.downloadUseCases = downloadUseCases
    }

    // MARK: - Download Operations

    /// Descarga una canción por su ID
    /// - Parameter songID: ID de la canción a descargar
    func download(songID: UUID) async {
        // Evitar descargas duplicadas
        guard activeTasksManager.tasks[songID] == nil else {
            print("⏭️ Descarga ya en progreso para \(songID)")
            return
        }

        // Crear tarea de descarga
        let task = Task { @MainActor in
            // Iniciar progreso en 0%
            downloadProgress[songID] = 0.0
            isDownloading = true
            downloadError = nil

            print("📥 Iniciando descarga: \(songID)")

            do {
                // Descargar usando UseCases
                try await downloadUseCases.downloadSong(songID) { [weak self] progress in
                    guard let self = self else { return }
                    // Actualizar progreso
                    self.downloadProgress[songID] = progress
                }

                // Completado - mostrar 100% brevemente
                downloadProgress[songID] = 1.0
                print("✅ Descarga completada: \(songID)")

                // Mantener barra en 100% por 0.5 segundos para feedback visual
                try? await Task.sleep(nanoseconds: 500_000_000)

                // Limpiar progreso
                downloadProgress[songID] = nil

            } catch {
                // Manejar error
                downloadProgress[songID] = nil
                downloadError = "Error descargando canción: \(error.localizedDescription)"
                print("❌ \(downloadError!)")
            }

            // Limpiar tarea
            activeTasksManager.tasks.removeValue(forKey: songID)

            // Actualizar flag de descarga
            isDownloading = !activeTasksManager.tasks.isEmpty
        }

        // Guardar tarea
        activeTasksManager.tasks[songID] = task
    }

    /// Descarga múltiples canciones
    /// - Parameter songIDs: IDs de las canciones a descargar
    func downloadMultiple(songIDs: [UUID]) async {
        for songID in songIDs {
            await download(songID: songID)
        }
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
        isDownloading = false
    }

    // MARK: - Error Handling

    /// Limpia el error de descarga
    func clearDownloadError() {
        downloadError = nil
    }

    // MARK: - Utilities

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

    // MARK: - Cleanup

    
    deinit {
        // Capturar las tareas activas antes de crear el Task para evitar capturar 'self'
        let tasksToCancel = activeTasksManager.tasks
        Task { @MainActor in
            for (_, task) in tasksToCancel {
                task.cancel()
            }
            print("🗑️ DownloadViewModel deinicializado - tareas canceladas")
        }
    }
}
