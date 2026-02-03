//
//  PlayerViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Solo maneja UI de reproducción y cola
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI del reproductor
/// Coordina PlayerUseCases y gestiona cola de reproducción, shuffle, repeat
/// Usa EventBus con AsyncStream para reactividad moderna
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
    private let eventBus: EventBusProtocol
    private let liveActivityService = LiveActivityService()

    // MARK: - Private State

    private var queueSongIDs: [UUID] = []
    private var currentSongEntity: SongEntity?
    private var lastNowPlayingUpdateTime: TimeInterval = 0
    private var lastPlaybackTime: TimeInterval = 0

    // MARK: - Tasks

    /// Task para observación de eventos (nonisolated para acceso en deinit)
    nonisolated(unsafe) private var playbackEventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(playerUseCases: PlayerUseCases, eventBus: EventBusProtocol) {
        self.playerUseCases = playerUseCases
        self.eventBus = eventBus
        startObservingEvents()
        setupLiveActivityHandlers()
    }

    // MARK: - Playback Control

    /// Reproduce una canción y establece la cola de reproducción
    func play(songID: UUID, queue: [SongUIModel]) async {
        do {
            // Establecer la cola (solo canciones descargadas)
            self.queueSongIDs = queue
                .filter { $0.isDownloaded }
                .map { $0.id }

            // Obtener la canción via UseCase
            guard let song = try await playerUseCases.getSongByID(songID),
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
            let otherSongIDs = queueSongIDs.filter { $0 != afterSongID }
            nextSongID = otherSongIDs.randomElement() ?? queueSongIDs.first
        } else {
            guard let idx = queueSongIDs.firstIndex(where: { $0 == afterSongID }) else { return }
            let nextIdx = (idx + 1) % queueSongIDs.count
            nextSongID = queueSongIDs[nextIdx]
        }

        if let songID = nextSongID {
            let queueUIModels = await getQueueUIModels()
            await play(songID: songID, queue: queueUIModels)
        }
    }

    private func playPreviousSong(beforeSongID: UUID) async {
        guard !queueSongIDs.isEmpty else { return }

        var prevSongID: UUID?

        if isShuffleEnabled {
            let otherSongIDs = queueSongIDs.filter { $0 != beforeSongID }
            prevSongID = otherSongIDs.randomElement() ?? queueSongIDs.first
        } else {
            guard let idx = queueSongIDs.firstIndex(where: { $0 == beforeSongID }) else { return }
            let prevIdx = (idx - 1 + queueSongIDs.count) % queueSongIDs.count
            prevSongID = queueSongIDs[prevIdx]
        }

        if let songID = prevSongID {
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
            print("🔁 Repeat One: Repitiendo canción")
            let queueUIModels = await getQueueUIModels()
            await play(songID: finishedSongID, queue: queueUIModels)

        case .repeatAll:
            print("🔁 Repeat All: Siguiente canción")
            await playNextSong(afterSongID: finishedSongID)

        case .off:
            guard let idx = queueSongIDs.firstIndex(where: { $0 == finishedSongID }) else {
                print("⚠️ No se encontró el índice de la canción")
                return
            }

            if isShuffleEnabled {
                print("🔀 Shuffle: Siguiente canción aleatoria")
                await playNextSong(afterSongID: finishedSongID)
            } else {
                if idx < queueSongIDs.count - 1 {
                    print("▶️ Modo normal: Siguiente canción (\(idx + 1)/\(queueSongIDs.count))")
                    await playNextSong(afterSongID: finishedSongID)
                } else {
                    print("⏹️ Última canción alcanzada. Deteniendo reproducción.")
                    isPlaying = false
                }
            }
        }
    }

    // MARK: - Event Observation (EventBus + AsyncStream)

    private func startObservingEvents() {
        playbackEventTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.eventBus.playbackEvents() {
                guard !Task.isCancelled else { break }
                await self.handlePlaybackEvent(event)
            }
        }
    }

    private func handlePlaybackEvent(_ event: PlaybackEvent) async {
        switch event {
        case .stateChanged(let playing, let songID):
            self.isPlaying = playing
            if let songID = songID {
                self.currentlyPlayingID = songID
            }
            self.updateLiveActivity()

        case .timeUpdated(let time, let duration):
            let isFirstDurationUpdate = self.songDuration == 0 && duration > 0
            self.songDuration = duration

            // Throttle: actualizar solo si el cambio es > 0.5 segundos
            if abs(time - self.lastPlaybackTime) > 0.5 {
                self.playbackTime = time
                self.lastPlaybackTime = time
            }

            // Primera actualización de duración: actualizar Now Playing inmediatamente
            if isFirstDurationUpdate {
                await self.playerUseCases.updateNowPlayingTime(currentTime: time, duration: duration)
                self.lastNowPlayingUpdateTime = CACurrentMediaTime()
                return
            }

            // Actualizar Now Playing cada 1 segundo
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastNowPlayingUpdateTime >= 1.0 {
                self.lastNowPlayingUpdateTime = currentTime
                await self.playerUseCases.updateNowPlayingTime(currentTime: time, duration: duration)
            }

        case .songFinished(let finishedSongID):
            self.playbackTime = self.songDuration
            await self.playNextAutomatically(finishedSongID: finishedSongID)

        case .remoteCommand(let command):
            await handleRemoteCommand(command)
        }
    }

    private func handleRemoteCommand(_ command: RemoteCommand) async {
        switch command {
        case .playPause:
            await togglePlayPause()
        case .next:
            await playNext()
        case .previous:
            await playPrevious()
        case .seek(let time):
            await seek(to: time)
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

    /// Mantener NotificationCenter para Live Activity (comunicación inter-proceso)
    /// Los widgets/Live Activity no pueden usar EventBus directamente
    private func setupLiveActivityHandlers() {
        // Play/Pause desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .playPauseFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Convertir a EventBus internamente
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.playPause))
            }
        }

        // Next desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .nextTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.next))
            }
        }

        // Previous desde Live Activity
        NotificationCenter.default.addObserver(
            forName: .previousTrackFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.previous))
            }
        }
    }

    // MARK: - Helpers

    private func getQueueUIModels() async -> [SongUIModel] {
        do {
            let entities = try await playerUseCases.getSongsByIDs(queueSongIDs)
            return entities.map { SongMapper.toUIModel($0) }
        } catch {
            print("⚠️ Error al obtener canciones de la cola: \(error)")
            return []
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    deinit {
        playbackEventTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        let service = liveActivityService
        Task { @MainActor in
            service.endActivity()
        }
    }
}
