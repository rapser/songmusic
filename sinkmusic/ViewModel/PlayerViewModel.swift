
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
    @Published var showPlayerView: Bool = false
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var equalizerBands: [EqualizerBand] = EqualizerBand.defaultBands
    @Published var selectedPreset: EqualizerPreset = .flat

    enum RepeatMode {
        case off, repeatAll, repeatOne
    }

    private let audioPlayerService: AudioPlayerService
    private let downloadService: DownloadService
    private let metadataService: MetadataService
    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = []

    weak var scrollResetter: ScrollStateResettable?

    init(
        audioPlayerService: AudioPlayerService = AudioPlayerService(),
        downloadService: DownloadService = DownloadService(),
        metadataService: MetadataService = MetadataService()
    ) {
        self.audioPlayerService = audioPlayerService
        self.downloadService = downloadService
        self.metadataService = metadataService
        setupSubscriptions()
    }

    func play(song: Song) {
        print("🎯 PlayerViewModel.play() - '\(song.title)'")

        guard song.isDownloaded else {
            print("❌ Canción no descargada")
            return
        }

        guard let url = downloadService.localURL(for: song.id) else {
            print("❌ No se pudo obtener URL local")
            return
        }

        // Capturar metadatos si no existen (para canciones ya descargadas antes del cambio)
        if song.duration == nil || song.artworkData == nil {
            Task {
                if let metadata = await metadataService.extractMetadata(from: url) {
                    song.title = metadata.title
                    song.artist = metadata.artist
                    song.album = metadata.album
                    song.author = metadata.author
                    song.duration = metadata.duration
                    song.artworkData = metadata.artwork
                }
            }
        }

        if currentlyPlayingID == song.id {
            // Toggle play/pause para la misma canción
            if isPlaying {
                audioPlayerService.pause()
            } else {
                audioPlayerService.play(songID: song.id, url: url)
            }
        } else {
            // Nueva canción - IMPORTANTE: Actualizar currentlyPlayingID ANTES de llamar al servicio
            // Esto previene que completion handlers obsoletos cambien el ID
            print("🆕 Cambiando a nueva canción")
            currentlyPlayingID = song.id
            audioPlayerService.play(songID: song.id, url: url)
        }

        scrollResetter?.resetScrollState()
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

    func updateSongsList(_ songs: [Song]) {
        self.allSongs = songs.filter { $0.isDownloaded }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .repeatAll
        case .repeatAll:
            repeatMode = .repeatOne
        case .repeatOne:
            repeatMode = .off
        }
    }

    func playNext(currentSong: Song, allSongs: [Song]) {
        let downloadedSongs = allSongs.filter { $0.isDownloaded }
        guard !downloadedSongs.isEmpty else { return }

        if isShuffleEnabled {
            // Modo aleatorio: selecciona una canción aleatoria DIFERENTE a la actual
            let otherSongs = downloadedSongs.filter { $0.id != currentSong.id }

            if !otherSongs.isEmpty {
                // Hay más canciones disponibles, elige una aleatoria
                if let randomSong = otherSongs.randomElement() {
                    print("🎲 Shuffle: Playing random song - \(randomSong.title)")
                    play(song: randomSong)
                }
            } else if downloadedSongs.count == 1 {
                // Solo hay una canción, reproducirla de nuevo
                print("🎲 Shuffle: Only one song, replaying - \(currentSong.title)")
                play(song: currentSong)
            }
        } else {
            // Modo secuencial
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let nextIdx = (idx + 1) % downloadedSongs.count
            play(song: downloadedSongs[nextIdx])
        }
    }

    func playPrevious(currentSong: Song, allSongs: [Song]) {
        let downloadedSongs = allSongs.filter { $0.isDownloaded }
        guard !downloadedSongs.isEmpty else { return }

        if isShuffleEnabled {
            // En modo aleatorio, también va a una canción aleatoria
            let otherSongs = downloadedSongs.filter { $0.id != currentSong.id }
            if let randomSong = otherSongs.randomElement() {
                play(song: randomSong)
            } else if let firstSong = downloadedSongs.first {
                play(song: firstSong)
            }
        } else {
            // Modo secuencial
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let prevIdx = (idx - 1 + downloadedSongs.count) % downloadedSongs.count
            play(song: downloadedSongs[prevIdx])
        }
    }

    private func playNextAutomatically(finishedSongID: UUID) {
        print("🔄 playNextAutomatically called - finishedSongID: \(finishedSongID)")
        print("🔄 allSongs count: \(allSongs.count)")
        print("🔄 isShuffleEnabled: \(isShuffleEnabled)")
        print("🔄 repeatMode: \(repeatMode)")

        guard let currentSong = allSongs.first(where: { $0.id == finishedSongID }) else {
            print("❌ Could not find finished song in allSongs")
            return
        }

        print("✅ Found song: \(currentSong.title)")

        switch repeatMode {
        case .repeatOne:
            print("🔁 Repeat One - Playing same song")
            play(song: currentSong)
        case .repeatAll:
            print("🔁 Repeat All - Playing next song")
            playNext(currentSong: currentSong, allSongs: allSongs)
        case .off:
            print("⏭️ Repeat Off - Checking if should play next")

            if isShuffleEnabled {
                // En modo shuffle sin repeat, SIEMPRE reproduce una canción aleatoria
                // No se detiene hasta que el usuario pause manualmente
                let downloadedSongs = allSongs.filter { $0.isDownloaded }
                if !downloadedSongs.isEmpty {
                    print("🔀 Shuffle mode - playing random song")
                    playNext(currentSong: currentSong, allSongs: allSongs)
                } else {
                    print("⏹️ No songs available, stopping")
                }
            } else {
                // En modo secuencial sin repeat, solo avanza si no es la última
                let downloadedSongs = allSongs.filter { $0.isDownloaded }
                guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else {
                    print("❌ Could not find song index")
                    return
                }
                print("📍 Current index: \(idx), Total songs: \(downloadedSongs.count)")
                if idx < downloadedSongs.count - 1 {
                    print("▶️ Playing next song")
                    playNext(currentSong: currentSong, allSongs: allSongs)
                } else {
                    print("⏹️ Last song, stopping playback")
                    // Detener la reproducción y resetear el estado
                    isPlaying = false
                    // Mantener el currentlyPlayingID para mostrar qué canción fue la última
                }
            }
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Equalizer Functions
    func updateBandGain(index: Int, gain: Double) {
        guard index < equalizerBands.count else { return }
        equalizerBands[index].gain = gain
        selectedPreset = .flat // Reset preset when manually adjusting
        audioPlayerService.applyEqualizerSettings(equalizerBands)
    }

    func applyPreset(_ preset: EqualizerPreset) {
        selectedPreset = preset
        let gains = preset.gains
        for (index, gain) in gains.enumerated() where index < equalizerBands.count {
            equalizerBands[index].gain = gain
        }
        audioPlayerService.applyEqualizerSettings(equalizerBands)
    }

    func resetEqualizer() {
        equalizerBands = EqualizerBand.defaultBands
        selectedPreset = .flat
        audioPlayerService.applyEqualizerSettings(equalizerBands)
    }

    private func setupSubscriptions() {
        audioPlayerService.onPlaybackStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isPlaying, songID) in
                self?.isPlaying = isPlaying
                // NO actualizar currentlyPlayingID aquí - ya se actualiza en play()
                // Esto previene que el servicio sobrescriba el ID cuando hay cambios rápidos
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
            .sink { [weak self] finishedSongID in
                self?.playNextAutomatically(finishedSongID: finishedSongID)
            }
            .store(in: &cancellables)
    }
}
