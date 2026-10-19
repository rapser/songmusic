//
//  PlayerViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  SOLID: Single Responsibility - Solo maneja UI de reproducción y cola
//

import Foundation
import SwiftUI
import os

/// ViewModel responsable de la UI del reproductor
/// Coordina PlayerUseCases y gestiona cola de reproducción, shuffle, repeat
/// Usa EventBus con AsyncStream para reactividad moderna
@MainActor
@Observable
final class PlayerViewModel: EventBusObservable {

    // MARK: - Published State

    /// Espejo de solo-UI del estado de reproducción. **No es fuente de verdad**: se escribe
    /// únicamente desde `.stateChanged` y jamás debe usarse para decidir si reproducir o
    /// pausar — para eso está `PlayerUseCases.isPlaying()`, que consulta al motor de audio.
    var isPlaying = false
    var currentlyPlayingID: UUID?

    /// Posición de reproducción. **Espejo directo del `PlaybackClock`**: aquí no se lleva
    /// un contador propio ni se interpola entre eventos. Un segundo reloj en la UI es
    /// exactamente lo que hacía que el reproductor de la app y el de la pantalla de bloqueo
    /// mostraran tiempos distintos.
    var progress: PlaybackProgress = .zero

    /// Atajos de lectura para las vistas. No tienen `setter`: la única forma de mover el
    /// tiempo es que lo mueva el reloj.
    var playbackTime: TimeInterval { progress.elapsed }
    var songDuration: TimeInterval { progress.duration }

    var showPlayerView: Bool = false
    var isShuffleEnabled = false
    var repeatMode: RepeatMode = .off

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Player")

    // MARK: - Dependencies

    private let playerUseCases: PlayerUseCases
    private(set) var eventBus: EventBusProtocol
    private let liveActivityService: LiveActivityServiceProtocol

    // MARK: - Private State

    private var queueSongIDs: [UUID] = []
    private var currentSong: SongUI?
    private var lastProgressPersistTime: TimeInterval = 0

    // MARK: - Tasks

    /// Task para observación de eventos
    @ObservationIgnored
    private var playbackEventTask: Task<Void, Never>?

    /// Tokens de los observers de Live Activity.
    ///
    /// `removeObserver(self)` **no** elimina los registrados con
    /// `addObserver(forName:object:queue:using:)` — hay que guardar el token que devuelven y
    /// quitarlos uno a uno. Sin esto seguían disparando después de destruir el ViewModel.
    @ObservationIgnored
    private var liveActivityTokens: [NSObjectProtocol] = []

    // MARK: - Initialization

    init(
        playerUseCases: PlayerUseCases,
        eventBus: EventBusProtocol,
        liveActivityService: LiveActivityServiceProtocol
    ) {
        self.playerUseCases = playerUseCases
        self.eventBus = eventBus
        self.liveActivityService = liveActivityService
        playbackEventTask = makeEventTask(stream: { $0.playbackEvents() },
                                          handler: { [weak self] in await self?.handlePlaybackEvent($0) })
        setupLiveActivityHandlers()
    }

    // MARK: - Playback Control

    /// Reproduce una canción y establece la cola de reproducción
    func play(songID: UUID, queue: [SongUI]) async {
        do {
            // Establecer la cola (solo canciones descargadas)
            self.queueSongIDs = queue
                .filter { $0.isDownloaded }
                .map { $0.id }

            // Obtener la canción via UseCase y convertir a UIModel
            guard let songEntity = try await playerUseCases.getSongByID(songID),
                  songEntity.isDownloaded else {
                return
            }

            currentSong = SongMapper.toUI(songEntity)

            // Comportamiento estilo Spotify: si presionas la canción actual, reinicia
            if currentlyPlayingID == songID && isPlaying {
                await playerUseCases.seek(to: 0)
                progress = PlaybackProgress(elapsed: 0, duration: progress.duration)
            } else {
                // Nueva canción
                progress = .zero
                currentlyPlayingID = songID

                try await playerUseCases.play(songID: songID)
            }

            // Actualizar Live Activity
            updateLiveActivity()

        } catch {
            logger.error("Error al reproducir canción: \(error)")
        }
    }

    func togglePlayPause() async {
        do {
            try await playerUseCases.togglePlayPause()
        } catch {
            logger.error("Error al toggle play/pause: \(error)")
        }
    }

    /// Continúa la canción actual desde donde se quedó (intención explícita de "play")
    func resume() async {
        do {
            try await playerUseCases.resume()
        } catch {
            logger.error("Error al reanudar: \(error)")
        }
    }

    func pause() async {
        await playerUseCases.pause()
        // Respaldo inmediato: si el usuario cierra la app justo después de pausar,
        // no dependemos del siguiente `timeUpdated` (que ya no llegará) para persistir.
        playerUseCases.persistCurrentPlaybackTime(progress.elapsed)
    }

    func stop() async {
        await playerUseCases.stop()
        currentlyPlayingID = nil
        isPlaying = false
        // Cerrar el reproductor grande: sin canción en curso no tiene nada que mostrar y
        // dejar el flag activo haría que se abriera solo al reproducir la próxima canción.
        showPlayerView = false
        currentSong = nil
        liveActivityService.endActivity()
    }

    func seek(to time: TimeInterval) async {
        await playerUseCases.seek(to: time)
        progress = PlaybackProgress(elapsed: time, duration: progress.duration)
    }

    /// Restaura la última canción escuchada y su posición al abrir la app.
    /// No inicia la reproducción: solo deja el mini reproductor listo con el
    /// tiempo donde el usuario se quedó (p.ej. 2:25) para que continúe al presionar play.
    func restoreLastPlaybackState() async {
        guard let (song, time) = await playerUseCases.restoreLastPlaybackState() else { return }

        currentSong = SongMapper.toUI(song)
        currentlyPlayingID = song.id
        progress = PlaybackProgress(elapsed: time, duration: song.duration ?? 0)
        isPlaying = false
    }

    /// Persiste de inmediato la posición actual, sin esperar al próximo `timeUpdated`.
    /// Se invoca cuando la app pasa a segundo plano para no perder precisión.
    func persistCurrentPlaybackState() {
        playerUseCases.persistCurrentPlaybackTime(progress.elapsed)
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
        guard !queueSongIDs.isEmpty else { return }

        switch repeatMode {
        case .repeatOne:
            let queueUIModels = await getQueueUIModels()
            await play(songID: finishedSongID, queue: queueUIModels)

        case .repeatAll:
            await playNextSong(afterSongID: finishedSongID)

        case .off:
            guard let idx = queueSongIDs.firstIndex(where: { $0 == finishedSongID }) else { return }

            if isShuffleEnabled {
                await playNextSong(afterSongID: finishedSongID)
            } else {
                if idx < queueSongIDs.count - 1 {
                    await playNextSong(afterSongID: finishedSongID)
                } else {
                    // Fin de la cola: pasar por el UseCase para que el motor de audio y el
                    // reproductor nativo se enteren, en vez de tocar solo el flag local.
                    await playerUseCases.pause()
                }
            }
        }
    }

    // MARK: - Event Observation (EventBus + AsyncStream)

    private func handlePlaybackEvent(_ event: PlaybackEvent) async {
        switch event {
        case .stateChanged(let playing, let songID):
            self.isPlaying = playing
            if let songID = songID {
                self.currentlyPlayingID = songID
            }
            self.updateLiveActivity()

        case .timeUpdated(let progress):
            // Se adopta tal cual, sin throttle ni redondeo: el valor ya viene acotado del
            // reloj y es el mismo que recibe la pantalla de bloqueo.
            self.progress = progress

            // Now Playing lo refresca AudioPlayerService; aquí solo persistimos el avance
            // (cada 1s) para poder retomar la canción al reabrir la app.
            let now = CACurrentMediaTime()
            if now - self.lastProgressPersistTime >= 1.0 {
                self.lastProgressPersistTime = now
                self.playerUseCases.persistCurrentPlaybackTime(progress.elapsed)
            }

        case .songFinished(let finishedSongID):
            self.progress = PlaybackProgress(elapsed: self.progress.duration,
                                             duration: self.progress.duration)
            await self.playNextAutomatically(finishedSongID: finishedSongID)

        case .remoteCommand(let command):
            await handleRemoteCommand(command)
        }
    }

    private func handleRemoteCommand(_ command: RemoteCommand) async {
        switch command {
        case .play:
            // Intención explícita de iOS: reanudar, nunca alternar.
            await resume()
        case .pause:
            // Pasa por `pause()` del VM para que también persista la posición.
            await pause()
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
        guard let song = currentSong else { return }
        let duration = progress.duration > 0 ? progress.duration : song.durationSeconds

        if isPlaying {
            liveActivityService.startActivity(
                songID: song.id,
                songTitle: song.title,
                artistName: song.artist,
                isPlaying: isPlaying,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: song.artworkSmallThumbnail
            )
        } else if !isPlaying && liveActivityService.hasActiveActivity {
            liveActivityService.updateActivity(
                songTitle: song.title,
                artistName: song.artist,
                isPlaying: false,
                currentTime: playbackTime,
                duration: duration,
                artworkThumbnail: song.artworkSmallThumbnail
            )
        }
    }

    /// Mantener NotificationCenter para Live Activity (comunicación inter-proceso)
    /// Los widgets/Live Activity no pueden usar EventBus directamente
    private func setupLiveActivityHandlers() {
        let commands: [(Notification.Name, RemoteCommand)] = [
            (.playPauseFromLiveActivity, .playPause),
            (.nextTrackFromLiveActivity, .next),
            (.previousTrackFromLiveActivity, .previous)
        ]

        liveActivityTokens = commands.map { name, command in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Convertir a EventBus internamente
                Task { @MainActor [weak self] in
                    self?.eventBus.emit(.remoteCommand(command))
                }
            }
        }
    }

    // MARK: - Helpers

    private func getQueueUIModels() async -> [SongUI] {
        do {
            let entities = try await playerUseCases.getSongsByIDs(queueSongIDs)
            return entities.map { SongMapper.toUI($0) }
        } catch {
            logger.warning("Error al obtener canciones de la cola: \(error)")
            return []
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        DurationFormatter.clock(time)
    }

    // MARK: - Cleanup

    deinit {
        playbackEventTask?.cancel()
        for token in liveActivityTokens {
            NotificationCenter.default.removeObserver(token)
        }
        let service = liveActivityService
        Task { @MainActor in
            service.endActivity()
        }
    }
}
