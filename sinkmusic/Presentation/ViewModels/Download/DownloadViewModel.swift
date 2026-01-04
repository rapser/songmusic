//
//  DownloadViewModel.swift
//  sinkmusic
//
//  Created by Clean Architecture Refactor
//  REEMPLAZO de SongListViewModel legacy
//

import Foundation

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

    /// Tareas de descarga activas para cancelación
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Initialization

    init(downloadUseCases: DownloadUseCases) {
        self.downloadUseCases = downloadUseCases
    }

    // MARK: - Download Operations

    /// Descarga una canción por su ID
    /// - Parameter songID: ID de la canción a descargar
    func download(songID: UUID) async {
        // Evitar descargas duplicadas
        guard activeTasks[songID] == nil else {
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
            activeTasks.removeValue(forKey: songID)

            // Actualizar flag de descarga
            isDownloading = !activeTasks.isEmpty
        }

        // Guardar tarea
        activeTasks[songID] = task
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
            if let task = activeTasks[songID] {
                task.cancel()
                activeTasks.removeValue(forKey: songID)
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
        isDownloading = !activeTasks.isEmpty
    }

    /// Cancela una descarga en progreso
    /// - Parameter songID: ID de la canción
    func cancelDownload(songID: UUID) {
        guard let task = activeTasks[songID] else { return }

        task.cancel()
        activeTasks.removeValue(forKey: songID)
        downloadProgress.removeValue(forKey: songID)

        // Actualizar flag de descarga
        isDownloading = !activeTasks.isEmpty

        print("⏸️ Descarga cancelada: \(songID)")
    }

    /// Cancela todas las descargas en progreso
    func cancelAllDownloads() {
        for (songID, task) in activeTasks {
            task.cancel()
            downloadProgress.removeValue(forKey: songID)
            print("⏸️ Descarga cancelada: \(songID)")
        }

        activeTasks.removeAll()
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
        return activeTasks[songID] != nil
    }

    /// Obtiene el progreso de una canción específica
    /// - Parameter songID: ID de la canción
    /// - Returns: Progreso (0.0...1.0) o nil si no está descargando
    func progress(for songID: UUID) -> Double? {
        return downloadProgress[songID]
    }

    // MARK: - Cleanup

    deinit {
        // Cancelar todas las tareas activas
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        print("🗑️ DownloadViewModel deinicializado - tareas canceladas")
    }
}
