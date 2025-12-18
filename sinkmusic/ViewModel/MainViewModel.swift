
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
            // Si no hay credenciales, solo detener la sincronización
            // NO eliminar canciones descargadas - el usuario puede querer conservarlas
            print("⚠️ No hay credenciales de Google Drive. La sincronización no se ejecutará.")
            print("ℹ️ Las canciones descargadas se conservarán hasta que el usuario las elimine manualmente desde Configuración.")
            isLoadingSongs = false
            return
        }

        isLoadingSongs = true

        Task {
            do {
                // Obtener canciones desde Google Drive
                let driveFiles = try await googleDriveService.fetchSongsFromFolder()

                // Imprimir ruta donde se guardan los archivos M4A
                if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let musicDirectory = documentsDirectory.appendingPathComponent("Music")
                    print("📁 Ruta de archivos M4A: \(musicDirectory.path)")
                }

                let descriptor = FetchDescriptor<Song>()

                guard let existingSongs = try? modelContext.fetch(descriptor) else {
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
                        }
                    } else {
                        let newSong = Song(title: driveFile.title, artist: driveFile.artist, fileID: driveFile.id)
                        modelContext.insert(newSong)
                        newSongsAdded += 1
                    }
                }

                isLoadingSongs = false
            } catch {
                // El error se manejará en la UI, por ejemplo mostrando un mensaje.
                // Ya no se recurre al catálogo local.
                isLoadingSongs = false
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

    private func syncWithLocalCatalog(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Song>()

        guard let existingSongs = try? modelContext.fetch(descriptor) else {
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
    }
}
