
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
    }
    
    func syncLibraryWithCatalog(modelContext: ModelContext) {
        isLoadingSongs = true

        Task {
            do {
                // Obtener canciones desde Google Drive
                let driveFiles = try await googleDriveService.fetchSongsFromFolder()

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
                isLoadingSongs = false

                // Fallback: usar SongCatalog si falla Google Drive
                syncWithLocalCatalog(modelContext: modelContext)
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
