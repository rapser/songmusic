//
//  AudioPlayerService.swift
//  sinkmusic
//
//  Refactored to emit events via EventBus (Clean Architecture)
//  No callbacks - All events via EventBus
//

import Foundation
import AVFoundation
import MediaPlayer

/// SOLID: Dependency Inversion - Depende de EventBusProtocol
@MainActor
final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, AudioPlayerProtocol, AVAudioPlayerDelegate {

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol

    // State management — aislado a @MainActor, no necesita lock
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?

    // Audio Engine: ecualizador + mixer para reproducción de alta fidelidad (estilo Tidal Hi-Fi)
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private let eq: AVAudioUnitEQ
    private let mixerNode: AVAudioMixerNode

    // State flags con sincronización
    private var useAudioEngine = true
    private var isFirstConnection = true
    private var currentScheduleID = UUID()
    private var wasPlayingBeforeInterruption = false
    private var seekOffset: TimeInterval = 0

    // Propiedad pública para verificar el estado de reproducción
    var isPlaying: Bool {
        return playerNode.isPlaying
    }

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        self.eq = AVAudioUnitEQ(numberOfBands: 6)
        self.mixerNode = AVAudioMixerNode()

        super.init()
        setupAudioSession()
        setupAudioEngine()
        setupRemoteCommandCenter()
        setupInterruptionHandling()
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // .playback + .default: reproductor principal (Lock Screen, Control Center)
            // con volumen de salida completo del hardware, igual que Spotify y Tidal.
            // .measurement reducía el volumen de salida del sistema — revertido.
            try audioSession.setCategory(.playback, mode: .default, options: [])

            // Solicitar la mayor sample rate soportada por el hardware del dispositivo.
            // En iPhone con AirPods Pro / auriculares Lightning esto puede llegar a 48000 Hz.
            try audioSession.setPreferredSampleRate(audioSession.sampleRate)

            try audioSession.setActive(true)
        } catch {
            // Error al configurar la sesión de audio
        }
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)
        audioEngine.attach(mixerNode)

        // Mixer neutro: pan centrado, volumen máximo, sin colorear el sonido.
        mixerNode.pan = 0.0
        mixerNode.outputVolume = 1.0

        // EQ completamente en bypass: señal sin tocar, fidelidad máxima.
        // El usuario puede activar bandas desde el ecualizador de la app si lo desea.
        // Tidal Hi-Fi no aplica ningún procesamiento de señal por defecto.
        for index in 0..<eq.bands.count {
            eq.bands[index].bypass = true
        }
    }

    func play(songID: UUID, url: URL) {
        // Asegurar sesión activa para que Lock Screen y Control Center muestren Now Playing
        try? AVAudioSession.sharedInstance().setActive(true)

        if currentlyPlayingID == songID {
            if !playerNode.isPlaying {
                playerNode.play()
                if !audioEngine.isRunning {
                    try? audioEngine.start()
                }
                startPlaybackTimer()
                eventBus.emit(.stateChanged(isPlaying: true, songID: currentlyPlayingID))
            }
        } else {
            do {
                audioFile = try AVAudioFile(forReading: url)

                guard let audioFile = audioFile else {
                    return
                }

                let fileFormat = audioFile.processingFormat

                // Formato estéreo estándar para la salida del mixer.
                // Evita que archivos mono o con masterización desbalanceada suenen
                // más en un canal del audífono que en el otro (comportamiento tipo Spotify).
                let stereoFormat = AVAudioFormat(
                    standardFormatWithSampleRate: fileFormat.sampleRate,
                    channels: 2
                )

                if !isFirstConnection {
                    playerNode.reset()

                    if audioEngine.isRunning {
                        audioEngine.stop()
                    }

                    audioEngine.disconnectNodeInput(audioEngine.mainMixerNode)
                    audioEngine.disconnectNodeInput(mixerNode)
                    audioEngine.disconnectNodeInput(eq)
                } else {
                    isFirstConnection = false
                }

                // Cadena Hi-Fi: playerNode → eq (bypass) → mixerNode (estéreo) → mainMixerNode
                // Sin efectos intermedios: señal lo más pura posible, igual que Tidal.
                let outFormat = stereoFormat ?? fileFormat
                audioEngine.connect(playerNode, to: eq, format: fileFormat)
                audioEngine.connect(eq, to: mixerNode, format: fileFormat)
                audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outFormat)

                // Pan neutro: canal izquierdo y derecho con igual peso
                playerNode.pan = 0

                audioEngine.prepare()

                let scheduleID = UUID()
                self.currentScheduleID = scheduleID

                playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        guard self.currentScheduleID == scheduleID else { return }
                        guard let currentID = self.currentlyPlayingID else { return }

                        self.playbackTimer?.invalidate()
                        self.playbackTimer = nil

                        self.eventBus.emit(.songFinished(currentID))
                    }
                }

                if !audioEngine.isRunning {
                    try audioEngine.start()
                }

                playerNode.play()

                self.currentlyPlayingID = songID
                self.seekOffset = 0
                startPlaybackTimer()
                eventBus.emit(.stateChanged(isPlaying: true, songID: songID))
            } catch {
                eventBus.emit(.stateChanged(isPlaying: false, songID: nil))
            }
        }
    }

    func pause() {
        playerNode.pause()
        playbackTimer?.invalidate()
        eventBus.emit(.stateChanged(isPlaying: false, songID: currentlyPlayingID))
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        playbackTimer?.invalidate()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil
        eventBus.emit(.stateChanged(isPlaying: false, songID: oldID))
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else {
            return
        }

        let wasPlaying = playerNode.isPlaying
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)

        playerNode.stop()
        playbackTimer?.invalidate()

        if startFrame < audioFile.length {
            let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

            self.seekOffset = time

            let scheduleID = UUID()
            self.currentScheduleID = scheduleID

            playerNode.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard self.currentScheduleID == scheduleID else { return }
                    guard let currentID = self.currentlyPlayingID else { return }

                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil

                    self.eventBus.emit(.songFinished(currentID))
                }
            }

            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            eventBus.emit(.timeUpdated(current: time, duration: duration))

            if wasPlaying {
                playerNode.play()
                startPlaybackTimer()
            }
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()

        playbackTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            // El closure del Timer es @Sendable — no podemos leer propiedades @MainActor aquí.
            // Despachamos todo al MainActor donde el acceso es seguro.
            Task { @MainActor [weak self] in
                guard let self,
                      let nodeTime = self.playerNode.lastRenderTime,
                      (nodeTime.isSampleTimeValid || nodeTime.isHostTimeValid),
                      let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime),
                      let audioFile = self.audioFile else {
                    return
                }
                let nodePlaybackTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                let currentTime = nodePlaybackTime + self.seekOffset
                let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                self.eventBus.emit(.timeUpdated(current: currentTime, duration: duration))
            }
        }

        RunLoop.current.add(playbackTimer!, forMode: .common)
    }

    // MARK: - Equalizer

    private static let eqFrequencies: [Float] = [60, 150, 400, 1000, 2400, 15000]

    func updateEqualizer(bands: [Float]) {
        for (index, gain) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].filterType = .parametric
            eq.bands[index].frequency = index < Self.eqFrequencies.count ? Self.eqFrequencies[index] : 1000
            eq.bands[index].bandwidth = 1.0
            eq.bands[index].gain = gain
            // Bypass si la banda está a 0 dB — señal sin tocar, fidelidad máxima
            eq.bands[index].bypass = (gain == 0)
        }
    }

    func applyEqualizerSettings(_ bands: [EqualizerBand]) {
        for (index, band) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].filterType = .parametric
            eq.bands[index].frequency = index < Self.eqFrequencies.count ? Self.eqFrequencies[index] : 1000
            eq.bands[index].bandwidth = 1.0
            eq.bands[index].gain = Float(band.gain)
            eq.bands[index].bypass = (band.gain == 0)
        }
    }

    // MARK: - AVAudioPlayerDelegate
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let finishedSongID = self.currentlyPlayingID else { return }
            self.currentlyPlayingID = nil
            self.eventBus.emit(.stateChanged(isPlaying: false, songID: finishedSongID))
            self.eventBus.emit(.songFinished(finishedSongID))
        }
    }

    // MARK: - Interruption Handling
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc nonisolated private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        let shouldResumeIfEnded: Bool? = {
            guard type == .ended else { return nil }
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                return AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            }
            return true
        }()

        Task { @MainActor [weak self] in
            guard let self else { return }

            switch type {
            case .began:
                if self.playerNode.isPlaying {
                    self.wasPlayingBeforeInterruption = true
                    self.pause()
                }

            case .ended:
                guard self.wasPlayingBeforeInterruption, shouldResumeIfEnded == true else {
                    self.wasPlayingBeforeInterruption = false
                    return
                }
                try? await Task.sleep(for: .seconds(1))
                guard let songID = self.currentlyPlayingID else { return }
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    if !self.audioEngine.isRunning { try self.audioEngine.start() }
                    self.playerNode.play()
                    self.startPlaybackTimer()
                    self.eventBus.emit(.stateChanged(isPlaying: true, songID: songID))
                } catch {
                    self.eventBus.emit(.stateChanged(isPlaying: false, songID: songID))
                }
                self.wasPlayingBeforeInterruption = false

            @unknown default:
                break
            }
        }
    }

    // MARK: - Now Playing Info & Remote Commands
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.playPause))
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.playPause))
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.next))
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.previous))
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.seek(position)))
                self?.seek(to: position)
            }
            return .success
        }
    }

    func updateNowPlayingInfo(title: String, artist: String, album: String?, duration: TimeInterval, currentTime: TimeInterval, artwork: Data?) {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist

        if let album = album, !album.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        // Evitar NaN/infinitos: el sistema puede hacer INVOP al asignar nowPlayingInfo
        let safeDuration = duration.isFinite && duration >= 0 ? duration : 0
        let safeCurrentTime = currentTime.isFinite && currentTime >= 0 ? currentTime : 0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: safeDuration)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: safeCurrentTime)

        let playbackRate = playerNode.isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: playbackRate)

        if let artworkData = artwork, let image = UIImage(data: artworkData) {
            let size = image.size
            // El sistema invoca el closure desde otro hilo: debe ser @Sendable y solo capturar Sendable (Data).
            let artworkImage = MPMediaItemArtwork(boundsSize: size) { @Sendable _ in
                UIImage(data: artworkData) ?? UIImage()
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkImage
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
