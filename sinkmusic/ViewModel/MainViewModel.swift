
import Foundation
import Combine
import SwiftData

@MainActor
protocol ScrollStateResettable: AnyObject {
    func resetScrollState()
}

@MainActor
class MainViewModel: ObservableObject, ScrollStateResettable {
    @Published var isScrolling: Bool = false
    @Published var isLoadingSongs: Bool = false
    var playerViewModel: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    private let googleDriveService = GoogleDriveService()

    init() {
        self.playerViewModel = PlayerViewModel()
        self.playerViewModel.scrollResetter = self
    }
    
    func resetScrollState() {
        isScrolling = false
        print("🔄 Scroll state reseteado desde protocolo")
    }
    
    func syncLibraryWithCatalog(modelContext: ModelContext) {
        print("🔄 Sincronizando la librería de canciones...")

        // TEMPORAL: Mostrar la ruta donde se guardan las canciones
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let musicPath = documentsPath.appendingPathComponent("Music")
            print("📂 RUTA DE CANCIONES: \(musicPath.path)")
            print("📂 Puedes abrir en Finder con: open \(musicPath.path)")
        }

        isLoadingSongs = true

        Task {
            do {
                // Obtener canciones desde Google Drive
                let driveFiles = try await googleDriveService.fetchSongsFromFolder()

                let descriptor = FetchDescriptor<Song>()

                guard let existingSongs = try? modelContext.fetch(descriptor) else {
                    print("❌ Error al leer la base de datos de canciones.")
                    isLoadingSongs = false
                    return
                }

                let existingSongsMap = Dictionary(uniqueKeysWithValues: existingSongs.map { ($0.fileID, $0) })

                var newSongsAdded = 0
                var songsUpdated = 0

                for driveFile in driveFiles {
                    if let existingSong = existingSongsMap[driveFile.id] {
                        // Solo actualizar título y artista si NO tiene metadatos extraídos
                        // Si tiene duration o artwork, significa que ya se extrajeron los metadatos reales
                        let hasMetadata = existingSong.duration != nil || existingSong.artworkData != nil

                        if !hasMetadata && (existingSong.title != driveFile.title || existingSong.artist != driveFile.artist) {
                            existingSong.title = driveFile.title
                            existingSong.artist = driveFile.artist
                            songsUpdated += 1
                            print("📝 Actualizando canción sin metadatos: '\(driveFile.title)'")
                        } else if hasMetadata {
                            print("✅ Canción '\(existingSong.title)' ya tiene metadatos, no sobrescribir")
                        }
                    } else {
                        let newSong = Song(title: driveFile.title, artist: driveFile.artist, fileID: driveFile.id)
                        modelContext.insert(newSong)
                        newSongsAdded += 1
                    }
                }

                if newSongsAdded > 0 || songsUpdated > 0 {
                    print("✅ Sync completa desde Google Drive. \(newSongsAdded) nuevas, \(songsUpdated) actualizadas.")
                } else {
                    print("✅ Sync completa desde Google Drive. Nada que actualizar.")
                }

                isLoadingSongs = false
            } catch {
                print("❌ Error al sincronizar con Google Drive: \(error.localizedDescription)")
                isLoadingSongs = false

                // Fallback: usar SongCatalog si falla Google Drive
                print("⚠️ Usando SongCatalog como fallback...")
                syncWithLocalCatalog(modelContext: modelContext)
            }
        }
    }

    private func syncWithLocalCatalog(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Song>()

        guard let existingSongs = try? modelContext.fetch(descriptor) else {
            print("❌ Error al leer la base de datos de canciones.")
            return
        }

        let existingSongsMap = Dictionary(uniqueKeysWithValues: existingSongs.map { ($0.fileID, $0) })
        let catalogSongs = SongCatalog.allSongs

        var newSongsAdded = 0
        var songsUpdated = 0

        for catalogSong in catalogSongs {
            if let existingSong = existingSongsMap[catalogSong.id] {
                // Solo actualizar título y artista si NO tiene metadatos extraídos
                let hasMetadata = existingSong.duration != nil || existingSong.artworkData != nil

                if !hasMetadata && (existingSong.title != catalogSong.title || existingSong.artist != catalogSong.artist) {
                    existingSong.title = catalogSong.title
                    existingSong.artist = catalogSong.artist
                    songsUpdated += 1
                }
            } else {
                let newSong = Song(title: catalogSong.title, artist: catalogSong.artist, fileID: catalogSong.id)
                modelContext.insert(newSong)
                newSongsAdded += 1
            }
        }

        if newSongsAdded > 0 || songsUpdated > 0 {
            print("✅ Sync completa con fallback. \(newSongsAdded) nuevas, \(songsUpdated) actualizadas.")
        } else {
            print("✅ Sync completa con fallback. Nada que actualizar.")
        }
    }
}
