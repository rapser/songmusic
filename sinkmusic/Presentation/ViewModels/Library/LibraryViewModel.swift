//
//  LibraryViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Maneja UI de la biblioteca
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de la biblioteca
/// Delega lógica de negocio a LibraryUseCases
/// Usa EventBus con AsyncStream para reactividad moderna
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Published State (Clean Architecture - UIModels only)

    var isLoadingSongs: Bool = false
    var syncError: SyncError?
    var syncErrorMessage: String?
    var songs: [SongUI] = []
    var libraryStats: LibraryStats?

    // MARK: - Dependencies

    private let libraryUseCases: LibraryUseCases
    private let eventBus: EventBusProtocol

    // MARK: - Tasks

    /// Task para observación de eventos
    @ObservationIgnored
    private var dataEventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(libraryUseCases: LibraryUseCases, eventBus: EventBusProtocol) {
        self.libraryUseCases = libraryUseCases
        self.eventBus = eventBus
        startObservingEvents()
        Task {
            await loadSongs()
            await loadStats()
        }
    }

    // MARK: - Library Operations

    /// Carga todas las canciones
    func loadSongs() async {
        do {
            let entities = try await libraryUseCases.getAllSongs()
            songs = entities.map { SongMapper.toUI($0) }
        } catch {
            print("❌ Error al cargar canciones: \(error)")
        }
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
            print("❌ Error al guardar color dominante: \(error)")
        }
    }

    /// Sincroniza con almacenamiento cloud
    func syncLibraryWithCatalog() async {
        // Verificar credenciales
        print("🔄 LibraryVM: Iniciando sincronización...")
        let hasCredentials = libraryUseCases.hasCredentials()
        print("🔑 LibraryVM: ¿hasCredentials? = \(hasCredentials)")

        guard hasCredentials else {
            print("⚠️ LibraryVM: Sin credenciales, abortando sync")
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

            print("✅ Sincronización completada: \(newSongsCount) nuevas canciones. Total canciones: \(songs.count)")

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
            print("❌ Error en sincronización: \(syncErrorMessage ?? "Error desconocido")")
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
                    print("❌ Error al borrar canción \(song.title): \(error)")
                }
            }

            await loadSongs()
            await loadStats()

            print("🗑️ Biblioteca local y archivos descargados limpiados.")

        } catch {
            print("❌ Error al limpiar biblioteca: \(error)")
        }
    }

    /// Elimina una canción específica
    func deleteSong(_ songID: UUID) async {
        do {
            try await libraryUseCases.deleteSong(songID)
            await loadSongs()
            await loadStats()
        } catch {
            print("❌ Error al eliminar canción: \(error)")
        }
    }

    /// Elimina múltiples canciones
    func deleteSongs(_ songIDs: [UUID]) async {
        do {
            try await libraryUseCases.deleteSongs(songIDs)
            await loadSongs()
            await loadStats()
        } catch {
            print("❌ Error al eliminar canciones: \(error)")
        }
    }

    // MARK: - Statistics

    /// Carga estadísticas de la biblioteca
    func loadStats() async {
        do {
            libraryStats = try await libraryUseCases.getLibraryStats()
        } catch {
            print("❌ Error al cargar estadísticas: \(error)")
        }
    }

    // MARK: - Event Observation (EventBus + AsyncStream)

    private func startObservingEvents() {
        dataEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.eventBus.dataEvents() {
                guard !Task.isCancelled else { break }
                await self.handleDataEvent(event)
            }
        }
    }

    private func handleDataEvent(_ event: DataChangeEvent) async {
        switch event {
        case .songsUpdated:
            await loadSongs()
            await loadStats()

        case .songDownloaded:
            await loadSongs()
            await loadStats()

        case .songDeleted:
            await loadSongs()
            await loadStats()

        case .playlistsUpdated:
            // No action needed for playlists in library
            break

        case .credentialsChanged:
            // Reload when credentials change
            await loadSongs()

        case .error:
            // Handle error if needed
            break
        }
    }

    // MARK: - Helpers

    func hasCredentials() -> Bool {
        return libraryUseCases.hasCredentials()
    }

    // MARK: - Cleanup

    deinit {
        dataEventTask?.cancel()
    }
}

// MARK: - Sync Error
// SyncError is defined in Core/Errors/SyncError.swift
