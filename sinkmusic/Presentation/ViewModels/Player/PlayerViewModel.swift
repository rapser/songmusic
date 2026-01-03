//
//  PlayerViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Solo maneja UI de reproducción y cola
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI del reproductor
/// Coordina PlayerUseCases y gestiona cola de reproducción, shuffle, repeat
@MainActor
@Observable
final class PlayerViewModel {

    // MARK: - Published State

    var isPlaying = false
    var currentlyPlayingID: UUID?
    var playbackTime: TimeInterval = 0
    var songDuration: TimeInterval = 0
    var showPlayerView: Bool = false
    var isShuffleEnabled = false
    var repeatMode: RepeatMode = .off

    // MARK: - Dependencies

    private let playerUseCases: PlayerUseCases
    private let songRepository: SongRepositoryProtocol
    private let liveActivityService = LiveActivityService()

    // MARK: - Private State

    private var allSongEntities: [SongEntity] = []
    private var currentSongEntity: SongEntity?
    private var lastNowPlayingUpdateTime: TimeInterval = 0
    private var lastPlaybackTime: TimeInterval = 0

    // MARK: - Initialization

    init(
        playerUseCases: PlayerUseCases,
        songRepository: SongRepositoryProtocol
    ) {
        self.playerUseCases = playerUseCases
        self.songRepository = songRepository
        setupObservers()
        setupLiveActivityHandlers()
    }

    // MARK: - Playback Control

    /// Reproduce una canción y establece la cola de reproducción
    func play(songID: UUID, queue: [SongEntity]) async {
        do {
            // Establecer la cola (solo canciones descargadas)
            self.allSongEntities = queue.filter { $0.isDownloaded }

            // Obtener la canción
            guard let song = try await songRepository.getByID(songID),
                  song.isDownloaded else {
                return
            }

            currentSongEntity = song

            // Comportamiento estilo Spotify: si presionas la canción actual, reinicia
            if currentlyPlayingID == songID && isPlaying {
                await playerUseCases.seek(to: 0)
                playbackTime = 0
                lastPlaybackTime = 0
            } else {
                // Nueva canción
                playbackTime = 0
                lastPlaybackTime = 0
                songDuration = 0
                currentlyPlayingID = songID

                try await playerUseCases.play(songID: songID)
            }

            // Actualizar Live Activity
            updateLiveActivity()

        } catch {
            print("❌ Error al reproducir canción: \(error)")
        }
    }

    func togglePlayPause() async {
        do {
            try await playerUseCases.togglePlayPause()
        } catch {
            print("❌ Error al toggle play/pause: \(error)")
        }
    }

    func pause() async {
        await playerUseCases.pause()
    }

    func stop() async {
        await playerUseCases.stop()
        currentlyPlayingID = nil
    }

    func seek(to time: TimeInterval) async {
        await playerUseCases.seek(to: time)
        playbackTime = time
        lastPlaybackTime = time
    }

    // MARK: - Queue Management

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

    func playNext() async {
        guard let currentSong = currentSongEntity else { return }
        await playNextSong(after: currentSong)
    }

    func playPrevious() async {
        guard let currentSong = currentSongEntity else { return }
        await playPreviousSong(before: currentSong)
    }

    private func playNextSong(after currentSong: SongEntity) async {
        guard !allSongEntities.isEmpty else { return }

        var nextSong: SongEntity?

        if isShuffleEnabled {
            // Modo aleatorio: canción diferente a la actual
            let otherSongs = allSongEntities.filter { $0.id != currentSong.id }
            nextSong = otherSongs.randomElement() ?? allSongEntities.first
        } else {
            // Modo secuencial
            guard let idx = allSongEntities.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let nextIdx = (idx + 1) % allSongEntities.count
            nextSong = allSongEntities[nextIdx]
        }

        if let songToPlay = nextSong {
            await play(songID: songToPlay.id, queue: allSongEntities)
        }
    }

    private func playPreviousSong(before currentSong: SongEntity) async {
        guard !allSongEntities.isEmpty else { return }

        var prevSong: SongEntity?

        if isShuffleEnabled {
            // Modo aleatorio
            let otherSongs = allSongEntities.filter { $0.id != currentSong.id }
            prevSong = otherSongs.randomElement() ?? allSongEntities.first
        } else {
            // Modo secuencial
            guard let idx = allSongEntities.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let prevIdx = (idx - 1 + allSongEntities.count) % allSongEntities.count
            prevSong = allSongEntities[prevIdx]
        }

        if let songToPlay = prevSong {
            await play(songID: songToPlay.id, queue: allSongEntities)
        }
    }

    private func playNextAutomatically(finishedSongID: UUID) async {
        guard let currentSong = allSongEntities.first(where: { $0.id == finishedSongID }) else {
            print("⚠️ Canción terminada no encontrada. ID: \(finishedSongID)")
            return
        }

        let downloadedSongs = allSongEntities.filter { $0.isDownloaded }

        guard !downloadedSongs.isEmpty else {
            print("⚠️ No hay canciones descargadas disponibles")
            return
        }

        switch repeatMode {
        case .repeatOne:
            // Repetir la misma canción
            print("🔁 Repeat One: Repitiendo '\(currentSong.title)'")
            await play(songID: currentSong.id, queue: allSongEntities)

        case .repeatAll:
            // Continuar y volver al inicio si es la última
            print("🔁 Repeat All: Siguiente canción")
            await playNextSong(after: currentSong)

        case .off:
            // Continuar hasta la última canción
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else {
                print("⚠️ No se encontró el índice de la canción")
                return
            }

            if isShuffleEnabled {
                // Shuffle sin repeat: continuar con aleatorias
                print("🔀 Shuffle: Siguiente canción aleatoria")
                await playNextSong(after: currentSong)
            } else {
                // Secuencial sin repeat: continuar hasta la última
                if idx < downloadedSongs.count - 1 {
                    print("▶️ Modo normal: Siguiente canción (\(idx + 1)/\(downloadedSongs.count))")
                    await playNextSong(after: currentSong)
                } else {
                    // Última canción, detener
                    print("⏹️ Última canción alcanzada. Deteniendo reproducción.")
                    isPlaying = false
                }
            }
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observar cambios de estado de reproducción
        playerUseCases.observePlaybackState { [weak self] isPlaying, songID in
            guard let self = self else { return }
            self.isPlaying = isPlaying
            self.updateLiveActivity()
        }

        // Observar cambios de tiempo
        playerUseCases.observePlaybackTime { [weak self] time, duration in
            guard let self = self else { return }

            let isFirstDurationUpdate = self.songDuration == 0 && duration > 0
            self.songDuration = duration

            // Throttle: actualizar solo si el cambio es > 0.5 segundos
            if abs(time - self.lastPlaybackTime) > 0.5 {
                self.playbackTime = time
                self.lastPlaybackTime = time
            }

            // Primera actualización de duración: actualizar Now Playing inmediatamente
            if isFirstDurationUpdate {
                Task { @MainActor in
                    await self.playerUseCases.updateNowPlayingTime(currentTime: time, duration: duration)
                }
                self.lastNowPlayingUpdateTime = CACurrentMediaTime()
                return
            }

            // Actualizar Now Playing cada 1 segundo
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastNowPlayingUpdateTime >= 1.0 {
                self.lastNowPlayingUpdateTime = currentTime
                Task { @MainActor in
                    await self.playerUseCases.updateNowPlayingTime(currentTime: time, duration: duration)
                }
            }
        }

        // Observar cuando termina una canción
        playerUseCases.observeSongFinished { [weak self] finishedSongID in
            guard let self = self else { return }
            self.playbackTime = self.songDuration
            Task { @MainActor in
                await self.playNextAutomatically(finishedSongID: finishedSongID)
            }
        }

        // Observar controles remotos
        playerUseCases.observeRemotePlayPause { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.togglePlayPause()
            }
        }

        playerUseCases.observeRemoteNext { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.playNext()
            }
        }

        playerUseCases.observeRemotePrevious { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.playPrevious()
            }
        }
    }

    // MARK: - Live Activity

    private func updateLiveActivity() {
        guard let song = currentSongEntity else { return }
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
        // Play/Pause desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .playPauseFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.togglePlayPause()
            }
        }

        // Next desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .nextTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.playNext()
            }
        }

        // Previous desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .previousTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.playPrevious()
            }
        }
    }

    // MARK: - Helpers

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor in
            liveActivityService.endActivity()
        }
    }
}

