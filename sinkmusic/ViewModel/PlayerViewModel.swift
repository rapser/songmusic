
import Foundation
import Combine
import AVFoundation
import SwiftData

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentlyPlayingID: UUID?
    @Published var playbackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    
    private let audioPlayerService: AudioPlayerService
    private let downloadService: DownloadService
    private var cancellables = Set<AnyCancellable>()

    init(
        audioPlayerService: AudioPlayerService = AudioPlayerService(),
        downloadService: DownloadService = DownloadService()
    ) {
        self.audioPlayerService = audioPlayerService
        self.downloadService = downloadService
        setupSubscriptions()
    }

    func play(song: Song) {
        guard song.isDownloaded,
              let url = downloadService.localURL(for: song.id) else { return }

        if currentlyPlayingID == song.id {
            if isPlaying {
                audioPlayerService.pause()
                isPlaying = false
            } else {
                audioPlayerService.play(songID: song.id, url: url)
                isPlaying = true
            }
        } else {
            audioPlayerService.play(songID: song.id, url: url)
            currentlyPlayingID = song.id   // 🔥 importante
            isPlaying = true               // 🔥 importante
        }
    }
    
    func pause() {
        audioPlayerService.pause()
        isPlaying = false
    }

    func stop() {
        audioPlayerService.stop()
        isPlaying = false
        currentlyPlayingID = nil
    }

    func seek(to time: TimeInterval) {
        audioPlayerService.seek(to: time)
    }

    func playNext(currentSong: Song, allSongs: [Song]) {
        guard let idx = allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
        let next = (idx + 1) % allSongs.count
        play(song: allSongs[next])
    }
    
    func playPrevious(currentSong: Song, allSongs: [Song]) {
        guard let idx = allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
        let prev = (idx - 1 + allSongs.count) % allSongs.count
        play(song: allSongs[prev])
    }

    private func setupSubscriptions() {
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
                // aquí podrías disparar autoplay next
            }
            .store(in: &cancellables)
    }
}

