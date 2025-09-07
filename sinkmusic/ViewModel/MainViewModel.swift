
import Foundation
import Combine
import SwiftData

@MainActor
class MainViewModel: ObservableObject {
    
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isPlaying = false
    @Published var currentlyPlayingID: UUID?
    @Published var playbackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    
    private let audioPlayerService: AudioPlayerService
    private let downloadService: DownloadService
    private var cancellables = Set<AnyCancellable>()

    init(audioPlayerService: AudioPlayerService = AudioPlayerService(), downloadService: DownloadService = DownloadService()) {
        self.audioPlayerService = audioPlayerService
        self.downloadService = downloadService
        setupSubscriptions()
    }

    func download(song: Song, modelContext: ModelContext) {
        guard !song.isDownloaded else { return }
        downloadProgress[song.id] = -1
        Task {
            do {
                _ = try await downloadService.download(song: song)
                song.isDownloaded = true
                // SwiftData guardará automáticamente este cambio en el hilo principal.
                downloadProgress[song.id] = nil
            } catch {
                print("Error al descargar \(song.title): \(error.localizedDescription)")
                downloadProgress[song.id] = nil
            }
        }
    }
    
    func syncLibraryWithCatalog(modelContext: ModelContext) {
        print("🔄 Sincronizando la librería de canciones...")
        let descriptor = FetchDescriptor<Song>()
        guard let existingSongs = try? modelContext.fetch(descriptor) else {
            print("Error al leer la base de datos de canciones.")
            return
        }
        
        var existingSongsMap = [String: Song]()
        for song in existingSongs {
            existingSongsMap[song.fileID] = song
        }
        
        let catalogSongs = SongCatalog.allSongs // Ahora es un diccionario [fileID: title]
        
        var newSongsAdded = 0
        var songsUpdated = 0
        
        for (fileID, newTitle) in catalogSongs {
            if let existingSong = existingSongsMap[fileID] {
                // La canción ya existe, verificar si el título ha cambiado
                if existingSong.title != newTitle {
                    existingSong.title = newTitle
                    songsUpdated += 1
                }
            } else {
                // La canción no existe, añadirla
                let newSong = Song(title: newTitle, fileID: fileID)
                modelContext.insert(newSong)
                newSongsAdded += 1
            }
        }
        
        if newSongsAdded > 0 || songsUpdated > 0 {
            print("✅ Sincronización completa. Se añadieron \(newSongsAdded) canciones nuevas y se actualizaron \(songsUpdated).")
        } else {
            print("✅ Sincronización completa. No hay canciones nuevas que añadir ni actualizar.")
        }
    }

    func play(song: Song) {
        guard song.isDownloaded, let url = downloadService.localURL(for: song.id) else { return }
        if currentlyPlayingID == song.id {
            if isPlaying { audioPlayerService.pause() } else { audioPlayerService.play(songID: song.id, url: url) }
        } else {
            audioPlayerService.play(songID: song.id, url: url)
        }
    }
    
    func pause() { audioPlayerService.pause() }
    func stop() { audioPlayerService.stop() }
    func seek(to time: TimeInterval) { audioPlayerService.seek(to: time) }

    func playNext(currentSong: Song, allSongs: [Song]) {
        guard let currentIndex = allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
        let nextIndex = (currentIndex + 1) % allSongs.count
        play(song: allSongs[nextIndex])
    }
    
    func playPrevious(currentSong: Song, allSongs: [Song]) {
        guard let currentIndex = allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
        let prevIndex = (currentIndex - 1 + allSongs.count) % allSongs.count
        play(song: allSongs[prevIndex])
    }

    private func setupSubscriptions() {
        downloadService.downloadProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (songID, progress) in self?.downloadProgress[songID] = progress }
            .store(in: &cancellables)

        audioPlayerService.onPlaybackStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isPlaying, songID) in
                self?.isPlaying = isPlaying
                self?.currentlyPlayingID = songID
            }
            .store(in: &cancellables)

        audioPlayerService.onPlaybackTimeChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (time, duration) in
                self?.playbackTime = time
                self?.songDuration = duration
            }
            .store(in: &cancellables)
        
        audioPlayerService.onSongFinished
            .receive(on: DispatchQueue.main)
            .sink {
                // La vista se encargará de llamar a playNext
            }
            .store(in: &cancellables)
    }
}
