
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
    private let liveActivityService = LiveActivityService()
    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = []
    private var currentSong: Song?

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
        setupLiveActivityHandlers()
    }

    func play(song: Song) {
        guard song.isDownloaded else {
            return
        }

        guard let url = downloadService.localURL(for: song.id) else {
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
                    song.artworkThumbnail = metadata.artworkThumbnail
                }
            }
        }

        // Guardar la canción actual
        currentSong = song

        if currentlyPlayingID == song.id {
            // Toggle play/pause para la misma canción
            if isPlaying {
                audioPlayerService.pause()
            } else {
                audioPlayerService.play(songID: song.id, url: url)
            }
        } else {
            currentlyPlayingID = song.id
            audioPlayerService.play(songID: song.id, url: url)
        }

        // Actualizar Now Playing Info
        updateNowPlayingInfo()

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
                    play(song: randomSong)
                }
            } else if downloadedSongs.count == 1 {
                // Solo hay una canción, reproducirla de nuevo
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
        guard let currentSong = allSongs.first(where: { $0.id == finishedSongID }) else {
            return
        }

        switch repeatMode {
        case .repeatOne:
            play(song: currentSong)
        case .repeatAll:
            playNext(currentSong: currentSong, allSongs: allSongs)
        case .off:

            if isShuffleEnabled {
                // En modo shuffle sin repeat, SIEMPRE reproduce una canción aleatoria
                // No se detiene hasta que el usuario pause manualmente
                let downloadedSongs = allSongs.filter { $0.isDownloaded }
                if !downloadedSongs.isEmpty {
                    playNext(currentSong: currentSong, allSongs: allSongs)
                }
            } else {
                // En modo secuencial sin repeat, solo avanza si no es la última
                let downloadedSongs = allSongs.filter { $0.isDownloaded }
                guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else {
                    return
                }
                if idx < downloadedSongs.count - 1 {
                    playNext(currentSong: currentSong, allSongs: allSongs)
                } else {
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
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        audioPlayerService.onPlaybackTimeChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (time, duration) in
                self?.playbackTime = time
                self?.songDuration = duration
            }
            .store(in: &cancellables)

        // Actualizar Now Playing Info cada segundo (throttle)
        audioPlayerService.onPlaybackTimeChanged
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        audioPlayerService.onSongFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] finishedSongID in
                self?.playNextAutomatically(finishedSongID: finishedSongID)
            }
            .store(in: &cancellables)

        // Suscribirse a los comandos remotos desde la pantalla de bloqueo
        audioPlayerService.onRemotePlayPause
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self, let song = self.currentSong else { return }
                self.play(song: song)
            }
            .store(in: &cancellables)

        audioPlayerService.onRemoteNext
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self, let song = self.currentSong else { return }
                self.playNext(currentSong: song, allSongs: self.allSongs)
            }
            .store(in: &cancellables)

        audioPlayerService.onRemotePrevious
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self, let song = self.currentSong else { return }
                self.playPrevious(currentSong: song, allSongs: self.allSongs)
            }
            .store(in: &cancellables)
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }

        // Asegurarse de que tenemos una duración válida
        let duration = songDuration > 0 ? songDuration : (song.duration ?? 0)

        audioPlayerService.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: duration,
            currentTime: playbackTime,
            artwork: song.artworkData
        )

        // Actualizar Live Activity
        updateLiveActivity()
    }

    private func updateLiveActivity() {
        guard let song = currentSong else { return }

        let duration = songDuration > 0 ? songDuration : (song.duration ?? 0)

        if isPlaying {
            // Iniciar o actualizar Live Activity
            // Usamos el thumbnail pequeño (< 1KB) en lugar del artwork completo
            liveActivityService.startActivity(
                songID: song.id,
                songTitle: song.title,
                artistName: song.artist,
                isPlaying: isPlaying,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: song.artworkThumbnail
            )
        } else if !isPlaying && liveActivityService.hasActiveActivity {
            // Actualizar estado a pausado
            liveActivityService.updateActivity(
                songTitle: song.title,
                artistName: song.artist,
                isPlaying: false,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: song.artworkThumbnail
            )
        }
    }

    private func setupLiveActivityHandlers() {
        // Escuchar notificaciones de los botones de Live Activity usando Combine
        NotificationCenter.default.publisher(for: .playPauseFromLiveActivity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let song = self.currentSong else { return }
                self.play(song: song)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .nextTrackFromLiveActivity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let song = self.currentSong else { return }
                self.playNext(currentSong: song, allSongs: self.allSongs)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .previousTrackFromLiveActivity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let song = self.currentSong else { return }
                self.playPrevious(currentSong: song, allSongs: self.allSongs)
            }
            .store(in: &cancellables)
    }

    deinit {
        let service = liveActivityService
        Task { @MainActor in
            service.endActivity()
        }
    }
}
