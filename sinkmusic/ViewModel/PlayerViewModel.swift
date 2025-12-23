
import Foundation
import AVFoundation
import SwiftData
import UIKit

/// Información de la canción actualmente reproduciéndose
/// Desacoplada de SwiftData para evitar re-renders innecesarios
private struct PlayingSongInfo {
    let id: UUID
    let title: String
    let artist: String
    let album: String?
    let author: String?
    let duration: TimeInterval?
    let artworkData: Data?
    let artworkThumbnail: Data?
}

/// ViewModel responsable ÚNICAMENTE de la reproducción de audio
/// SOLID: Single Responsibility Principle - Solo maneja reproducción, no metadatos ni ecualizador
@MainActor
class PlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentlyPlayingID: UUID?
    @Published var playbackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    @Published var showPlayerView: Bool = false
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode {
        case off, repeatAll, repeatOne
    }

    // SOLID: Dependency Inversion - depende de abstracciones, no de implementaciones concretas
    // Nota: audioPlayerService es 'var' porque necesitamos asignar sus callbacks en setupCallbacks()
    private var audioPlayerService: AudioPlayerProtocol
    private let liveActivityService = LiveActivityService()
    private var allSongs: [Song] = []
    private var currentSongInfo: PlayingSongInfo?
    private var currentSongURL: URL? // Almacena la URL para reanudar reproducción
    private var lastNowPlayingUpdateTime: TimeInterval = 0
    private var lastPlaybackTime: TimeInterval = 0 // Para throttling de actualizaciones
    private var modelContext: ModelContext?

    init(
        audioPlayerService: AudioPlayerProtocol = AudioPlayerService()
    ) {
        self.audioPlayerService = audioPlayerService
        setupCallbacks()
        setupLiveActivityHandlers()
    }

    /// Configura el ModelContext para poder actualizar estadísticas de reproducción
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Reproduce una canción y establece la cola de reproducción actual
    /// NOTA: El artwork debe ser cacheado externamente por MetadataCacheViewModel
    func play(song: Song, from url: URL, in queue: [Song]) {
        guard song.isDownloaded else {
            return
        }

        // Establecer la nueva cola de reproducción, filtrando solo las descargadas
        self.allSongs = queue.filter { $0.isDownloaded }

        // Guardar URL para poder reanudar reproducción
        currentSongURL = url

        // Crear snapshot de datos desacoplado de SwiftData
        currentSongInfo = PlayingSongInfo(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            author: song.author,
            duration: song.duration,
            artworkData: song.artworkData,
            artworkThumbnail: song.artworkThumbnail
        )

        // Comportamiento estilo Spotify cuando presionas desde el listado:
        // Si presionas la canción que ya está tocando, reinicia desde el principio
        if currentlyPlayingID == song.id && isPlaying {
            // Reiniciar la canción desde el principio
            audioPlayerService.seek(to: 0)
            playbackTime = 0
            lastPlaybackTime = 0
        } else {
            // Nueva canción o canción pausada
            playbackTime = 0
            lastPlaybackTime = 0
            currentlyPlayingID = song.id
            audioPlayerService.play(songID: song.id, url: url)
        }

        // Actualizar Now Playing Info con los datos actuales
        updateNowPlayingInfo()

        // Incrementar contador de reproducciones
        incrementPlayCount(for: song)
    }

    /// Incrementa el contador de reproducciones de una canción
    private func incrementPlayCount(for song: Song) {
        guard let context = modelContext else { return }

        Task { @MainActor in
            song.playCount += 1
            song.lastPlayedAt = Date()

            do {
                try context.save()
                print("📊 PlayCount actualizado: \(song.title) - \(song.playCount) reproducciones")
            } catch {
                print("❌ Error al actualizar playCount: \(error)")
            }
        }
    }

    func togglePlayPause() {
        guard let songInfo = currentSongInfo,
              let url = currentSongURL else { return }

        if isPlaying {
            pause()
        } else {
            // Reanudar reproducción sin reiniciar
            audioPlayerService.play(songID: songInfo.id, url: url)
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

        var nextSong: Song?

        if isShuffleEnabled {
            // Modo aleatorio: selecciona una canción aleatoria DIFERENTE a la actual
            let otherSongs = self.allSongs.filter { $0.id != currentSong.id }
            nextSong = otherSongs.randomElement() ?? self.allSongs.first
        } else {
            // Modo secuencial
            guard let idx = self.allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let nextIdx = (idx + 1) % self.allSongs.count
            nextSong = self.allSongs[nextIdx]
        }
        
        if let songToPlay = nextSong, let url = songToPlay.localURL {
            // La cola no cambia, se mantiene la actual
            play(song: songToPlay, from: url, in: self.allSongs)
        }
    }

    func playPrevious(currentSong: Song, allSongs: [Song]) {
        // Usar allSongs cacheado en lugar de filtrar cada vez
        guard !self.allSongs.isEmpty else { return }

        var prevSong: Song?

        if isShuffleEnabled {
            // En modo aleatorio, también va a una canción aleatoria
            let otherSongs = self.allSongs.filter { $0.id != currentSong.id }
            prevSong = otherSongs.randomElement() ?? self.allSongs.first
        } else {
            // Modo secuencial
            guard let idx = self.allSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let prevIdx = (idx - 1 + self.allSongs.count) % self.allSongs.count
            prevSong = self.allSongs[prevIdx]
        }
        
        if let songToPlay = prevSong, let url = songToPlay.localURL {
            // La cola no cambia, se mantiene la actual
            play(song: songToPlay, from: url, in: self.allSongs)
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
            if let url = currentSong.localURL {
                // La cola no cambia
                play(song: currentSong, from: url, in: self.allSongs)
            }

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
        lastPlaybackTime = time
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

            // Throttle: solo actualizar playbackTime si el cambio es significativo (> 0.5 segundos)
            // Esto previene el warning "onChange tried to update multiple times per frame"
            // 0.5 segundos es suficiente para una UI fluida sin sobrecargar SwiftUI
            if abs(time - self.lastPlaybackTime) > 0.5 {
                self.playbackTime = time
                self.lastPlaybackTime = time
            }

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
            guard let self = self,
                  let playingID = self.currentlyPlayingID,
                  let song = self.allSongs.first(where: { $0.id == playingID }) else { return }
            self.playNext(currentSong: song, allSongs: self.allSongs)
        }

        // Callback para canción anterior desde control remoto
        audioPlayerService.onRemotePrevious = { [weak self] in
            guard let self = self,
                  let playingID = self.currentlyPlayingID,
                  let song = self.allSongs.first(where: { $0.id == playingID }) else { return }
            self.playPrevious(currentSong: song, allSongs: self.allSongs)
        }
    }

    private func updateNowPlayingInfo() {
        guard let songInfo = currentSongInfo else { return }
        let duration = songDuration > 0 ? songDuration : (songInfo.duration ?? 0)

        audioPlayerService.updateNowPlayingInfo(
            title: songInfo.title,
            artist: songInfo.artist,
            album: songInfo.album,
            duration: duration,
            currentTime: playbackTime,
            artwork: songInfo.artworkData
        )
    }

    private func updateLiveActivity() {
        guard let songInfo = currentSongInfo else { return }
        let duration = songDuration > 0 ? songDuration : (songInfo.duration ?? 0)

        if isPlaying {
            liveActivityService.startActivity(
                songID: songInfo.id,
                songTitle: songInfo.title,
                artistName: songInfo.artist,
                isPlaying: isPlaying,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: songInfo.artworkThumbnail
            )
        } else if !isPlaying && liveActivityService.hasActiveActivity {
            liveActivityService.updateActivity(
                songTitle: songInfo.title,
                artistName: songInfo.artist,
                isPlaying: false,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: songInfo.artworkThumbnail
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
                guard let self = self,
                      let playingID = self.currentlyPlayingID,
                      let song = self.allSongs.first(where: { $0.id == playingID }) else { return }
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
                guard let self = self,
                      let playingID = self.currentlyPlayingID,
                      let song = self.allSongs.first(where: { $0.id == playingID }) else { return }
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
