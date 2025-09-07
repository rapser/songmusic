
import Foundation
import Combine
import SwiftData

@MainActor
class MainViewModel: ObservableObject {
    @Published var isScrolling: Bool = false
    let playerViewModel: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()

    init(playerViewModel: PlayerViewModel? = nil) {
        if let provided = playerViewModel {
            self.playerViewModel = provided
        } else {
            self.playerViewModel = PlayerViewModel() // ✅ se crea en MainActor
        }
    }
    
    func syncLibraryWithCatalog(modelContext: ModelContext) {
        print("🔄 Sincronizando la librería de canciones...")
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
                if existingSong.title != catalogSong.title || existingSong.artist != catalogSong.artist {
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
            print("✅ Sync completa. \(newSongsAdded) nuevas, \(songsUpdated) actualizadas.")
        } else {
            print("✅ Sync completa. Nada que actualizar.")
        }
    }
}


