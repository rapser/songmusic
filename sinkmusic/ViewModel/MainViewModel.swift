
import Foundation
import SwiftData

@MainActor
protocol ScrollStateResettable: AnyObject {
    func resetScrollState()
}

enum SyncError: Error {
    case invalidCredentials
    case emptyFolder
    case networkError(String)
}

@MainActor
class MainViewModel: ObservableObject, ScrollStateResettable {
    @Published var isScrolling: Bool = false
    @Published var isLoadingSongs: Bool = false
    @Published var syncError: SyncError?
    @Published var syncErrorMessage: String?
    var playerViewModel: PlayerViewModel
    private let googleDriveService = GoogleDriveService()
    private let keychainService = KeychainService.shared

    init() {
        self.playerViewModel = PlayerViewModel()
        self.playerViewModel.scrollResetter = self
    }
    
    func resetScrollState() {
        isScrolling = false
    }
    
    func syncLibraryWithCatalog(modelContext: ModelContext) {
        guard keychainService.hasGoogleDriveCredentials else {
            syncError = nil
            syncErrorMessage = nil
            isLoadingSongs = false
            return
        }

        isLoadingSongs = true
        syncError = nil
        syncErrorMessage = nil

        Task {
            do {
                // Obtener canciones desde Google Drive
                let driveFiles = try await googleDriveService.fetchSongsFromFolder()

                // Validar que haya canciones en la carpeta
                if driveFiles.isEmpty {
                    await MainActor.run {
                        syncError = .emptyFolder
                        syncErrorMessage = "La carpeta de Google Drive está vacía o no contiene archivos de audio"
                        isLoadingSongs = false
                    }
                    return
                }

                // Imprimir ruta donde se guardan los archivos M4A
                if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let musicDirectory = documentsDirectory.appendingPathComponent("Music")
                    print("📁 Ruta de archivos M4A: \(musicDirectory.path)")
                }

                let descriptor = FetchDescriptor<Song>()

                guard let existingSongs = try? modelContext.fetch(descriptor) else {
                    await MainActor.run {
                        isLoadingSongs = false
                    }
                    return
                }

                let existingSongsMap = Dictionary(uniqueKeysWithValues: existingSongs.map { ($0.fileID, $0) })

                var newSongsAdded = 0
                var songsUpdated = 0

                for driveFile in driveFiles {
                    if let existingSong = existingSongsMap[driveFile.id] {
                        let hasMetadata = existingSong.duration != nil || existingSong.artworkData != nil

                        if !hasMetadata && (existingSong.title != driveFile.title || existingSong.artist != driveFile.artist) {
                            existingSong.title = driveFile.title
                            existingSong.artist = driveFile.artist
                            songsUpdated += 1
                        }
                    } else {
                        let newSong = Song(title: driveFile.title, artist: driveFile.artist, fileID: driveFile.id)
                        modelContext.insert(newSong)
                        newSongsAdded += 1
                        print("📝 Nueva canción: \"\(driveFile.title)\" (FileID: \(driveFile.id.prefix(10))...)")
                    }
                }

                // Detectar posibles duplicados por título similar
                let allTitles = driveFiles.map { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                let titleCounts = Dictionary(grouping: allTitles) { $0 }.mapValues { $0.count }
                let potentialDuplicates = titleCounts.filter { $0.value > 1 }

                if !potentialDuplicates.isEmpty {
                    print("⚠️ ADVERTENCIA: Se encontraron posibles duplicados en Google Drive:")
                    for (title, count) in potentialDuplicates {
                        let matchingSongs = driveFiles.filter {
                            $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == title
                        }
                        print("   • \"\(title)\" aparece \(count) veces:")
                        for song in matchingSongs {
                            print("     - \"\(song.title)\" (FileID: \(song.id.prefix(10))...)")
                        }
                    }
                    print("💡 Sugerencia: Elimina los archivos duplicados de tu Google Drive para evitar descargas duplicadas")
                }

                await MainActor.run {
                    syncError = nil
                    syncErrorMessage = nil
                    isLoadingSongs = false
                    print("✅ Sincronización completada: \(newSongsAdded) nuevas, \(songsUpdated) actualizadas")
                }
            } catch {
                await MainActor.run {
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
        }
    }

    func clearLibrary(modelContext: ModelContext) {
        Task {
            let descriptor = FetchDescriptor<Song>()
            if let existingSongs = try? modelContext.fetch(descriptor) {
                for song in existingSongs {
                    // Borrar el archivo de audio físico si existe
                    do {
                        try googleDriveService.deleteDownload(for: song.id)
                    } catch {
                        print("No se pudo borrar el archivo para la canción \(song.title): \(error.localizedDescription)")
                    }

                    // Borrar el registro de la base de datos
                    modelContext.delete(song)
                }

                try? modelContext.save()
                print("🗑️ Biblioteca local y archivos descargados limpiados.")
            }
        }
    }
}
