
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
    var playerViewModel: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    
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
