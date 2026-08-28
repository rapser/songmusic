//
//  NowPlayingCenter.swift
//  sinkmusic
//
//  Infrastructure — todo lo relacionado con la pantalla de bloqueo / Centro de Control:
//  `MPNowPlayingInfoCenter` (metadata + tiempo) y `MPRemoteCommandCenter` (comandos remotos).
//  Extraído de `AudioPlayerService` (P2.13) para que ese quede solo con el motor de audio.
//

import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingCenter {

    private let eventBus: EventBusProtocol

    /// Metadata fija de la canción actual (título/artista/álbum/artwork/duración).
    /// Se construye una vez por canción; los refrescos de tiempo solo mutan este diccionario.
    private var base: [String: Any] = [:]

    /// Artwork ya convertido, junto al `Data` del que salió, para reutilizarlo mientras
    /// no cambie la canción (convertirlo es caro).
    private var cachedArtworkData: Data?

    private var lastPush: CFTimeInterval = 0

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
    }

    // MARK: - Metadata

    /// Fija la metadata de la canción actual. Se llama una vez por canción, no en cada tick.
    func setMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?,
        elapsed: TimeInterval,
        isPlaying: Bool,
        realDuration: TimeInterval
    ) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist

        if let album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        // Evitar NaN/infinitos: el sistema puede hacer INVOP al asignar nowPlayingInfo.
        let safeDuration = duration.isFinite && duration >= 0 ? duration : 0
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: safeDuration)
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // Reconstruir el artwork solo si cambió.
        if let artworkData = artwork {
            if artworkData != cachedArtworkData || base[MPMediaItemPropertyArtwork] == nil {
                if let image = UIImage(data: artworkData) {
                    // El sistema invoca el closure desde otro hilo: @Sendable y solo captura `Data`.
                    let art = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in
                        UIImage(data: artworkData) ?? UIImage()
                    }
                    info[MPMediaItemPropertyArtwork] = art
                    cachedArtworkData = artworkData
                }
            } else if let existing = base[MPMediaItemPropertyArtwork] {
                info[MPMediaItemPropertyArtwork] = existing
            }
        } else {
            cachedArtworkData = nil
        }

        base = info
        push(elapsed: elapsed, isPlaying: isPlaying, realDuration: realDuration)
    }

    /// Refresca solo el tiempo transcurrido (y la duración si se conoce).
    func updateTime(elapsed: TimeInterval, duration: TimeInterval?, isPlaying: Bool, realDuration: TimeInterval) {
        if let duration, duration.isFinite, duration > 0 {
            base[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
        }
        push(elapsed: elapsed, isPlaying: isPlaying, realDuration: realDuration)
    }

    /// Único punto que escribe en `MPNowPlayingInfoCenter`.
    ///
    /// El orden importa: primero `nowPlayingInfo` (para que iOS tenga el tiempo fresco) y
    /// después `playbackState`. Al revés, iOS extrapola un frame desde el valor anterior.
    func push(elapsed: TimeInterval, isPlaying: Bool, realDuration: TimeInterval) {
        var info = base

        let safeElapsed = elapsed.isFinite && elapsed >= 0 ? elapsed : 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: safeElapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: isPlaying ? 1.0 : 0.0)
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: 1.0)

        // La duración real del archivo es más fiable que la metadata de la canción.
        if realDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: realDuration)
            base[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: realDuration)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        lastPush = CACurrentMediaTime()
    }

    /// Push con throttle: no hace nada si hace menos de `minInterval` del último push.
    /// Lo usa el tick del timer de progreso (~10 Hz) para refrescar el widget a ~1 Hz.
    func pushIfStale(elapsed: TimeInterval, isPlaying: Bool, realDuration: TimeInterval, minInterval: CFTimeInterval) {
        guard CACurrentMediaTime() - lastPush >= minInterval else { return }
        push(elapsed: elapsed, isPlaying: isPlaying, realDuration: realDuration)
    }

    func clear() {
        base = [:]
        cachedArtworkData = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    // MARK: - Remote commands

    /// Registra los targets del `MPRemoteCommandCenter`. Cada comando solo emite su
    /// `RemoteCommand` por el `EventBus` — la acción real la ejecuta el ViewModel.
    func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        // Intenciones explícitas: iOS manda play o pause según el estado que él cree que
        // tenemos. Traducirlas a un toggle hacía que un `pauseCommand` acabara reproduciendo.
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.play)) }
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.pause)) }
            return .success
        }

        // Botón central de AirPods / auriculares: aquí sí es un alternar de verdad.
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.playPause)) }
            return .success
        }

        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.next)) }
            return .success
        }

        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.previous)) }
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.eventBus.emit(.remoteCommand(.seek(position))) }
            return .success
        }
    }
}
