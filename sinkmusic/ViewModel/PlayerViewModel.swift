
import Foundation
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
    private var allSongs: [Song] = []
    private var currentSong: Song?
    private var lastNowPlayingUpdateTime: TimeInterval = 0

    weak var scrollResetter: ScrollStateResettable?

    init(
        audioPlayerService: AudioPlayerService = AudioPlayerService(),
        downloadService: DownloadService = DownloadService(),
        metadataService: MetadataService = MetadataService()
    ) {
        self.audioPlayerService = audioPlayerService
        self.downloadService = downloadService
        self.metadataService = metadataService
        setupCallbacks()
        setupLiveActivityHandlers()
    }

    func play(song: Song) {
        guard song.isDownloaded else {
            return
        }

        guard let url = downloadService.localURL(for: song.id) else {
            return
        }

        currentSong = song

        // Comportamiento estilo Spotify cuando presionas desde el listado:
        // Si presionas la canción que ya está tocando, reinicia desde el principio
        if currentlyPlayingID == song.id && isPlaying {
            // Reiniciar la canción desde el principio
            audioPlayerService.seek(to: 0)
            playbackTime = 0
        } else {
            // Nueva canción o canción pausada
            playbackTime = 0
            currentlyPlayingID = song.id
            audioPlayerService.play(songID: song.id, url: url)
        }

        // Actualizar metadata inmediatamente con los datos actuales
        updateNowPlayingInfo()

        scrollResetter?.resetScrollState()

        // Extraer metadata en background con baja prioridad (después de iniciar reproducción)
        if song.duration == nil || song.artworkData == nil {
            Task(priority: .utility) { [weak self] in
                guard let self = self else { return }
                if let metadata = await self.metadataService.extractMetadata(from: url) {
                    song.title = metadata.title
                    song.artist = metadata.artist
                    song.album = metadata.album
                    song.author = metadata.author
                    song.duration = metadata.duration
                    song.artworkData = metadata.artwork
                    song.artworkThumbnail = metadata.artworkThumbnail
                    song.artworkMediumThumbnail = metadata.artworkMediumThumbnail

                    // Actualizar info después de cargar metadata
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    func togglePlayPause() {
        guard let song = currentSong else { return }

        if isPlaying {
            pause()
        } else {
            // Reanudar reproducción sin reiniciar
            guard let url = downloadService.localURL(for: song.id) else { return }
            audioPlayerService.play(songID: song.id, url: url)
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


    func updateSongsList(_ songs: [Song]) {
        let downloadedSongs = songs.filter { $0.isDownloaded }
        self.allSongs = downloadedSongs
        print("📋 Lista actualizada: \(downloadedSongs.count) canciones descargadas")
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
        // Usar allSongs cacheado en lugar de filtrar cada vez
        guard !self.allSongs.isEmpty else { return }

        if isShuffleEnabled {
            // Modo aleatorio: selecciona una canción aleatoria DIFERENTE a la actual
            let otherSongs = self.allSongs.filter { $0.id != currentSong.id }

            if !otherSongs.isEmpty {
                // Hay más canciones disponibles, elige una aleatoria
                if let randomSong = otherSongs.randomElement() {
                    play(song: randomSong)
                }
            } else if self.allSongs.count == 1 {
                // Solo hay una canción, reproducirla de nuevo
                play(song: currentSong)
            }
        } else {
            // Modo secuencial
            guard let idx = self.allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let nextIdx = (idx + 1) % self.allSongs.count
            play(song: self.allSongs[nextIdx])
        }
    }

    func playPrevious(currentSong: Song, allSongs: [Song]) {
        // Usar allSongs cacheado en lugar de filtrar cada vez
        guard !self.allSongs.isEmpty else { return }

        if isShuffleEnabled {
            // En modo aleatorio, también va a una canción aleatoria
            let otherSongs = self.allSongs.filter { $0.id != currentSong.id }
            if let randomSong = otherSongs.randomElement() {
                play(song: randomSong)
            } else if let firstSong = self.allSongs.first {
                play(song: firstSong)
            }
        } else {
            // Modo secuencial
            guard let idx = self.allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let prevIdx = (idx - 1 + self.allSongs.count) % self.allSongs.count
            play(song: self.allSongs[prevIdx])
        }
    }

    private func playNextAutomatically(finishedSongID: UUID) {
        // Buscar la canción actual en allSongs
        guard let currentSong = allSongs.first(where: { $0.id == finishedSongID }) else {
            print("⚠️ Canción terminada no encontrada en allSongs. ID: \(finishedSongID)")
            print("   allSongs count: \(allSongs.count)")
            return
        }

        // Filtrar solo canciones descargadas
        let downloadedSongs = allSongs.filter { $0.isDownloaded }

        guard !downloadedSongs.isEmpty else {
            print("⚠️ No hay canciones descargadas disponibles")
            return
        }

        switch repeatMode {
        case .repeatOne:
            // Repetir la misma canción
            print("🔁 Repeat One: Repitiendo '\(currentSong.title)'")
            play(song: currentSong)

        case .repeatAll:
            // Continuar reproduciendo y volver al inicio si es la última
            print("🔁 Repeat All: Siguiente canción")
            playNext(currentSong: currentSong, allSongs: allSongs)

        case .off:
            // Comportamiento por defecto: continuar hasta la última canción
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else {
                print("⚠️ No se encontró el índice de la canción actual")
                return
            }

            if isShuffleEnabled {
                // En shuffle sin repeat: continuar con canciones aleatorias
                print("🔀 Shuffle: Siguiente canción aleatoria")
                playNext(currentSong: currentSong, allSongs: allSongs)
            } else {
                // En secuencial sin repeat: continuar hasta la última canción
                if idx < downloadedSongs.count - 1 {
                    // Hay más canciones, reproducir la siguiente
                    print("▶️ Modo normal: Siguiente canción (\(idx + 1)/\(downloadedSongs.count))")
                    playNext(currentSong: currentSong, allSongs: allSongs)
                } else {
                    // Es la última canción, detener la reproducción
                    print("⏹️ Última canción alcanzada. Deteniendo reproducción.")
                    isPlaying = false
                }
            }
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Seek
    func seek(to time: TimeInterval) {
        audioPlayerService.seek(to: time)
        playbackTime = time
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

    private func setupCallbacks() {
        // Callback para cambios en el estado de reproducción
        audioPlayerService.onPlaybackStateChanged = { [weak self] isPlaying, songID in
            guard let self = self else { return }
            self.isPlaying = isPlaying
            self.updateNowPlayingInfo()
            self.updateLiveActivity()
        }

        // Callback para cambios en el tiempo de reproducción
        audioPlayerService.onPlaybackTimeChanged = { [weak self] time, duration in
            guard let self = self else { return }
            self.playbackTime = time
            self.songDuration = duration

            // Throttle manual: actualizar Now Playing Info solo cada 1 segundo
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastNowPlayingUpdateTime >= 1.0 {
                self.lastNowPlayingUpdateTime = currentTime
                self.updateNowPlayingInfo()
            }
        }

        // Callback para cuando termina una canción
        audioPlayerService.onSongFinished = { [weak self] finishedSongID in
            guard let self = self else { return }
            self.playbackTime = self.songDuration
            self.playNextAutomatically(finishedSongID: finishedSongID)
        }

        // Callback para play/pause remoto
        audioPlayerService.onRemotePlayPause = { [weak self] in
            guard let self = self else { return }
            self.togglePlayPause()
        }

        // Callback para siguiente canción desde control remoto
        audioPlayerService.onRemoteNext = { [weak self] in
            guard let self = self, let song = self.currentSong else { return }
            self.playNext(currentSong: song, allSongs: self.allSongs)
        }

        // Callback para canción anterior desde control remoto
        audioPlayerService.onRemotePrevious = { [weak self] in
            guard let self = self, let song = self.currentSong else { return }
            self.playPrevious(currentSong: song, allSongs: self.allSongs)
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        let duration = songDuration > 0 ? songDuration : (song.duration ?? 0)

        audioPlayerService.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: duration,
            currentTime: playbackTime,
            artwork: song.artworkData
        )
    }

    private func updateLiveActivity() {
        guard let song = currentSong else { return }
        let duration = songDuration > 0 ? songDuration : (song.duration ?? 0)

        if isPlaying {
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
        // Observer para play/pause desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .playPauseFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.togglePlayPause()
            }
        }

        // Observer para siguiente canción desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .nextTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let song = self.currentSong else { return }
                self.playNext(currentSong: song, allSongs: self.allSongs)
            }
        }

        // Observer para canción anterior desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .previousTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let song = self.currentSong else { return }
                self.playPrevious(currentSong: song, allSongs: self.allSongs)
            }
        }
    }

    deinit {
        // Remover observers de NotificationCenter
        NotificationCenter.default.removeObserver(self)

        // Finalizar Live Activity
        let service = liveActivityService
        Task { @MainActor in
            service.endActivity()
        }
    }
}
