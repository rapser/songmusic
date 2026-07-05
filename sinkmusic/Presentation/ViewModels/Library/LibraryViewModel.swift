//
//  LibraryViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Maneja UI de la biblioteca
//

import Foundation
import SwiftUI
import os

/// ViewModel responsable de la UI de la biblioteca
/// Delega mutaciones a LibraryUseCases y lectura reactiva a LibraryReadStoreProtocol
/// (que reacciona a cambios de SwiftData sin pasar por el EventBus global).
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var isLoadingSongs: Bool = false
    var syncError: SyncError?
    var syncErrorMessage: String?
    var songs: [SongUI] = []
    var libraryStats: LibraryStats?

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Library")

    // MARK: - Dependencies

    private let libraryUseCases: LibraryUseCases
    private let readStore: LibraryReadStoreProtocol

    // MARK: - Tasks

    /// Task para observar cambios reactivos del ReadStore
    @ObservationIgnored
    private var changesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(libraryUseCases: LibraryUseCases, readStore: LibraryReadStoreProtocol) {
        self.libraryUseCases = libraryUseCases
        self.readStore = readStore
        changesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in readStore.changes() {
                guard !Task.isCancelled else { break }
                await self.reloadLibrary()
            }
        }
        Task {
            await loadSongs()
            await loadStats()
        }
    }

    // MARK: - Library Operations

    /// Carga todas las canciones
    func loadSongs() async {
        await loadAndAssign(
            fetch: { try await readStore.allSongs() },
            map: { $0.map(SongMapper.toUI) },
            assign: { songs = $0 },
            onError: { [self] in logger.error("Error al cargar canciones: \($0)") }
        )
    }

    /// Devuelve el artwork en resolución completa de una canción (para player grande).
    /// Se usa solo para la canción en reproducción para no cargar todas las carátulas en memoria.
    func getArtworkData(songID: UUID) async -> Data? {
        (try? await libraryUseCases.getSongByID(songID))?.artworkData
    }

    /// Persiste el color dominante calculado del artwork (solo cuando aún no está guardado).
    /// La primera vez se calcula y guarda; en siguientes cargas la lista usará el color guardado.
    func persistDominantColorIfNeeded(songID: UUID, artworkData: Data?) async {
        guard let artworkData = artworkData,
              let rgb = Color.dominantColorRGB(from: artworkData) else { return }
        do {
            try await libraryUseCases.updateDominantColor(songID: songID, red: rgb.r, green: rgb.g, blue: rgb.b)
            if let idx = songs.firstIndex(where: { $0.id == songID }) {
                songs[idx] = songs[idx].with(dominantColor: Color(red: rgb.r, green: rgb.g, blue: rgb.b))
            }
        } catch {
            logger.error("Error al guardar color dominante: \(error)")
        }
    }

    /// Sincroniza con almacenamiento cloud
    func syncLibraryWithCatalog() async {
        // Verificar credenciales
        let hasCredentials = libraryUseCases.hasCredentials()

        guard hasCredentials else {
            logger.info("Sin credenciales, abortando sync")
            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false
            return
        }

        isLoadingSongs = true
        syncError = nil
        syncErrorMessage = nil

        do {
            // Sincronizar con almacenamiento cloud
            let newSongsCount = try await libraryUseCases.syncWithCloudStorage()

            // Recargar canciones
            await loadSongs()
            await loadStats()

            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false

            logger.info("Sincronización completada: \(newSongsCount) nuevas canciones. Total: \(self.songs.count)")

        } catch {
            let errorString = error.localizedDescription.lowercased()

            if errorString.contains("401") || errorString.contains("403") || errorString.contains("unauthorized") {
                syncError = .invalidCredentials
                syncErrorMessage = "Las credenciales son inválidas o han expirado"
            } else if errorString.contains("404") || errorString.contains("not found") {
                syncError = .emptyFolder
                syncErrorMessage = "No se encontró la carpeta o no contiene archivos de audio"
            } else {
                syncError = .networkError(error.localizedDescription)
                syncErrorMessage = "Error de conexión: \(error.localizedDescription)"
            }

            isLoadingSongs = false
            logger.error("Error en sincronización: \(self.syncErrorMessage ?? "Error desconocido")")
        }
    }

    /// Limpia toda la biblioteca
    func clearLibrary() async {
        do {
            let allSongs = try await libraryUseCases.getAllSongs()

            for song in allSongs {
                do {
                    try await libraryUseCases.deleteSong(song.id)
                } catch {
                    logger.error("Error al borrar canción \(song.title): \(error)")
                }
            }

            await loadSongs()
            await loadStats()

            logger.info("Biblioteca local y archivos descargados limpiados.")

        } catch {
            logger.error("Error al limpiar biblioteca: \(error)")
        }
    }

    /// Elimina una canción específica
    func deleteSong(_ songID: UUID) async {
        do {
            try await libraryUseCases.deleteSong(songID)
            await loadSongs()
            await loadStats()
        } catch {
            logger.error("Error al eliminar canción: \(error)")
        }
    }

    /// Elimina múltiples canciones en modo best-effort — continúa aunque alguna falle.
    func deleteSongs(_ songIDs: [UUID]) async {
        let result = await libraryUseCases.deleteSongs(songIDs)
        await loadSongs()
        await loadStats()
        if result.hasFailures {
            logger.error("\(result.failureCount) canciones no pudieron eliminarse")
        }
    }

    // MARK: - Statistics

    /// Carga estadísticas de la biblioteca
    func loadStats() async {
        do {
            libraryStats = try await readStore.stats()
        } catch {
            logger.error("Error al cargar estadísticas: \(error)")
        }
    }

    private func reloadLibrary() async {
        await loadSongs()
        await loadStats()
    }

    // MARK: - Helpers

    func hasCredentials() -> Bool {
        return libraryUseCases.hasCredentials()
    }

    // MARK: - Cleanup

    deinit {
        changesTask?.cancel()
    }
}

// MARK: - Sync Error
// SyncError is defined in Core/Errors/SyncError.swift
