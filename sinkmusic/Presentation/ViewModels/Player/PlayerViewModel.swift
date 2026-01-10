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

    private var queueSongIDs: [UUID] = []  // Solo almacenamos IDs, no entities
    private var currentSongEntity: SongEntity?  // Mantenemos temporalmente para Live Activity
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
    func play(songID: UUID, queue: [SongUIModel]) async {
        do {
            // Establecer la cola (solo canciones descargadas) - ahora solo guardamos IDs
            self.queueSongIDs = queue
                .filter { $0.isDownloaded }
                .map { $0.id }

            // Obtener la canción del repository
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
        guard let currentSongID = currentlyPlayingID else { return }
        await playNextSong(afterSongID: currentSongID)
    }

    func playPrevious() async {
        guard let currentSongID = currentlyPlayingID else { return }
        await playPreviousSong(beforeSongID: currentSongID)
    }

    private func playNextSong(afterSongID: UUID) async {
        guard !queueSongIDs.isEmpty else { return }

        var nextSongID: UUID?

        if isShuffleEnabled {
            // Modo aleatorio: canción diferente a la actual
            let otherSongIDs = queueSongIDs.filter { $0 != afterSongID }
            nextSongID = otherSongIDs.randomElement() ?? queueSongIDs.first
        } else {
            // Modo secuencial
            guard let idx = queueSongIDs.firstIndex(where: { $0 == afterSongID }) else { return }
            let nextIdx = (idx + 1) % queueSongIDs.count
            nextSongID = queueSongIDs[nextIdx]
        }

        if let songID = nextSongID {
            // Obtener todas las canciones de la cola para pasarlas a play()
            let queueUIModels = await getQueueUIModels()
            await play(songID: songID, queue: queueUIModels)
        }
    }

    private func playPreviousSong(beforeSongID: UUID) async {
        guard !queueSongIDs.isEmpty else { return }

        var prevSongID: UUID?

        if isShuffleEnabled {
            // Modo aleatorio
            let otherSongIDs = queueSongIDs.filter { $0 != beforeSongID }
            prevSongID = otherSongIDs.randomElement() ?? queueSongIDs.first
        } else {
            // Modo secuencial
            guard let idx = queueSongIDs.firstIndex(where: { $0 == beforeSongID }) else { return }
            let prevIdx = (idx - 1 + queueSongIDs.count) % queueSongIDs.count
            prevSongID = queueSongIDs[prevIdx]
        }

        if let songID = prevSongID {
            // Obtener todas las canciones de la cola para pasarlas a play()
            let queueUIModels = await getQueueUIModels()
            await play(songID: songID, queue: queueUIModels)
        }
    }

    private func playNextAutomatically(finishedSongID: UUID) async {
        guard !queueSongIDs.isEmpty else {
            print("⚠️ No hay canciones en la cola")
            return
        }

        switch repeatMode {
        case .repeatOne:
            // Repetir la misma canción
            print("🔁 Repeat One: Repitiendo canción")
            let queueUIModels = await getQueueUIModels()
            await play(songID: finishedSongID, queue: queueUIModels)

        case .repeatAll:
            // Continuar y volver al inicio si es la última
            print("🔁 Repeat All: Siguiente canción")
            await playNextSong(afterSongID: finishedSongID)

        case .off:
            // Continuar hasta la última canción
            guard let idx = queueSongIDs.firstIndex(where: { $0 == finishedSongID }) else {
                print("⚠️ No se encontró el índice de la canción")
                return
            }

            if isShuffleEnabled {
                // Shuffle sin repeat: continuar con aleatorias
                print("🔀 Shuffle: Siguiente canción aleatoria")
                await playNextSong(afterSongID: finishedSongID)
            } else {
                // Secuencial sin repeat: continuar hasta la última
                if idx < queueSongIDs.count - 1 {
                    print("▶️ Modo normal: Siguiente canción (\(idx + 1)/\(queueSongIDs.count))")
                    await playNextSong(afterSongID: finishedSongID)
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

    /// Obtiene las canciones de la cola desde el repository y las convierte a UIModels
    private func getQueueUIModels() async -> [SongUIModel] {
        var uiModels: [SongUIModel] = []

        for songID in queueSongIDs {
            do {
                if let entity = try await songRepository.getByID(songID) {
                    uiModels.append(SongMapper.toUIModel(entity))
                }
            } catch {
                print("⚠️ Error al obtener canción \(songID): \(error)")
            }
        }

        return uiModels
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
        let service = liveActivityService
        Task { @MainActor in
            service.endActivity()
        }
    }
}

