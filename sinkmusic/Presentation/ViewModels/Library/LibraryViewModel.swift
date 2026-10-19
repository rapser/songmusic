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

    /// Pausa la reactividad de las cuatro listas durante un borrado masivo: una recarga al
    /// final en vez de una por canción.
    private let bulkReloadGate: BulkReloadGate

    // MARK: - Tasks

    /// Task para observar cambios reactivos del ReadStore
    @ObservationIgnored
    private var changesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        libraryUseCases: LibraryUseCases,
        readStore: LibraryReadStoreProtocol,
        bulkReloadGate: BulkReloadGate
    ) {
        self.libraryUseCases = libraryUseCases
        self.readStore = readStore
        self.bulkReloadGate = bulkReloadGate
        changesTask = ReactiveReload.loop(readStore.changes()) { [weak self] in
            await self?.reloadLibrary()
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
            assign: { if songs != $0 { songs = $0 } },
            onError: { [self] in logger.error("Error al cargar canciones: \($0)") }
        )
    }

    /// Devuelve el artwork en resolución completa de una canción (para player grande).
    /// Se usa solo para la canción en reproducción para no cargar todas las carátulas en memoria.
    func getArtworkData(songID: UUID) async -> Data? {
        (try? await libraryUseCases.getSongByID(songID))?.artworkData
    }

    /// Calcula y persiste el color dominante de una canción que todavía no lo tiene.
    ///
    /// Desde que el color se calcula al ingerir (`MetadataService`), esto solo hace falta
    /// para las canciones que ya estaban en la biblioteca antes: un relleno perezoso, una
    /// vez por canción y solo cuando se abre su reproductor.
    ///
    /// El análisis va en `Task.detached`: decodificar y muestrear la imagen no tiene por
    /// qué bloquear el main actor, que es justo donde está la animación de apertura del
    /// reproductor.
    func persistDominantColorIfNeeded(songID: UUID, artworkData: Data?) async {
        guard let artworkData else { return }

        let rgb = await Task.detached(priority: .utility) {
            DominantColorService.extract(from: artworkData)
        }.value

        guard let rgb else { return }

        do {
            try await libraryUseCases.updateDominantColor(
                songID: songID, red: rgb.red, green: rgb.green, blue: rgb.blue
            )
            if let idx = songs.firstIndex(where: { $0.id == songID }) {
                songs[idx] = songs[idx].with(dominantColor: Color(rgb))
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

            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false

            logger.info("Sincronización completada: \(newSongsCount) nuevas canciones. Total: \(self.songs.count)")

        } catch {
            // La capa Data ya entrega `SyncError` tipado; el `catch` genérico es un
            // salvavidas por si llega algo sin clasificar.
            let classified = (error as? SyncError) ?? .networkError(error.localizedDescription)
            syncError = classified
            syncErrorMessage = classified.userMessage
            isLoadingSongs = false
            logger.error("Error en sincronización: \(classified.userMessage, privacy: .public)")
        }
    }

    /// Limpia toda la biblioteca.
    ///
    /// Borra canción por canción, y cada borrado hace su propio `save()`. Sin la puerta,
    /// cada uno despertaba a las cuatro tiendas del read-side: vaciar 500 canciones eran
    /// 500 cascadas de recargas, todas describiendo un estado intermedio que nadie va a
    /// ver. Con la puerta se colapsan en una sola señal al terminar.
    func clearLibrary() async {
        bulkReloadGate.suspend()
        defer { bulkReloadGate.resume() }

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
    /// Igual que `clearLibrary()`: una recarga al final, no una por canción.
    func deleteSongs(_ songIDs: [UUID]) async {
        bulkReloadGate.suspend()
        defer { bulkReloadGate.resume() }

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
