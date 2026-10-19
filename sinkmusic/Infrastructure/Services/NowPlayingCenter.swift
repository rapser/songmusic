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
    ///
    /// `duration` es la de la metadata de la canción, que puede venir vacía o equivocada; la
    /// buena es `progress.duration`, medida sobre el archivo. Aquí solo sirve de respaldo
    /// mientras el archivo aún no está cargado.
    func setMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?,
        progress: PlaybackProgress,
        isPlaying: Bool
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
        push(progress, isPlaying: isPlaying)
    }

    /// Único punto que escribe en `MPNowPlayingInfoCenter`.
    ///
    /// Recibe la posición del `PlaybackClock` — la misma que ve la UI de la app — en vez de
    /// un tiempo suelto: es lo que garantiza que los dos reproductores muestren lo mismo.
    ///
    /// El orden importa: primero `nowPlayingInfo` (para que iOS tenga el tiempo fresco) y
    /// después `playbackState`. Al revés, iOS extrapola un frame desde el valor anterior.
    func push(_ progress: PlaybackProgress, isPlaying: Bool) {
        var info = base

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: progress.elapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: isPlaying ? 1.0 : 0.0)
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: 1.0)

        // La duración medida sobre el archivo es más fiable que la de la metadata.
        if progress.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: progress.duration)
            base[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: progress.duration)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        lastPush = CACurrentMediaTime()
    }

    /// Push con throttle: no hace nada si hace menos de `minInterval` del último push.
    /// Lo usa el tick del timer de progreso (~10 Hz) para refrescar el widget a ~1 Hz.
    ///
    /// iOS no se limita a mostrar lo que se le manda: extrapola desde `elapsed` con
    /// `playbackRate` y su propio reloj. Refrescar a 1 Hz con la posición real del motor es
    /// lo que mantiene esa extrapolación pegada a la verdad.
    func pushIfStale(_ progress: PlaybackProgress, isPlaying: Bool, minInterval: CFTimeInterval) {
        guard CACurrentMediaTime() - lastPush >= minInterval else { return }
        push(progress, isPlaying: isPlaying)
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
