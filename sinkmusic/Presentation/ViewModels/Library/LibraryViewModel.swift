//
//  LibraryViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI de la biblioteca
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI de la biblioteca
/// Delega lógica de negocio a LibraryUseCases
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Published State

    var isLoadingSongs: Bool = false
    var syncError: SyncError?
    var syncErrorMessage: String?
    var songs: [SongEntity] = []
    var libraryStats: LibraryStats?

    // MARK: - Dependencies

    private let libraryUseCases: LibraryUseCases

    // MARK: - Initialization

    init(libraryUseCases: LibraryUseCases) {
        self.libraryUseCases = libraryUseCases
        setupObservers()
        Task {
            await loadSongs()
            await loadStats()
        }
    }

    // MARK: - Library Operations

    /// Carga todas las canciones
    func loadSongs() async {
        do {
            songs = try await libraryUseCases.getAllSongs()
        } catch {
            print("❌ Error al cargar canciones: \(error)")
        }
    }

    /// Sincroniza con Google Drive
    func syncLibraryWithCatalog() async {
        // Verificar credenciales
        guard libraryUseCases.hasCredentials() else {
            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false
            return
        }

        isLoadingSongs = true
        syncError = nil
        syncErrorMessage = nil

        do {
            // Sincronizar con Google Drive
            let newSongsCount = try await libraryUseCases.syncWithGoogleDrive()

            // Recargar canciones
            await loadSongs()
            await loadStats()

            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false

            print("✅ Sincronización completada: \(newSongsCount) nuevas canciones")

        } catch {
            let errorString = error.localizedDescription.lowercased()

            if errorString.contains("401") || errorString.contains("403") || errorString.contains("unauthorized") {
                syncError = .invalidCredentials
                syncErrorMessage = "Las credenciales de Google Drive son inválidas o han expirado"
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

    // MARK: - Observers

    private func setupObservers() {
        // Observar cambios en la biblioteca
        libraryUseCases.observeLibraryChanges { [weak self] updatedSongs in
            guard let self = self else { return }
            self.songs = updatedSongs
            Task {
                await self.loadStats()
            }
        }
    }

    // MARK: - Helpers

    func hasCredentials() -> Bool {
        return libraryUseCases.hasCredentials()
    }
}

// MARK: - Sync Error

enum SyncError: Error, Equatable {
    case invalidCredentials
    case emptyFolder
    case networkError(String)

    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials),
             (.emptyFolder, .emptyFolder):
            return true
        case (.networkError(let lhsMsg), .networkError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
