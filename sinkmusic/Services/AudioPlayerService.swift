
import Foundation
import AVFoundation
import MediaPlayer

final class AudioPlayerService: NSObject, AudioPlayerProtocol, AVAudioPlayerDelegate {

    // Swift 6 Concurrency: Callbacks en lugar de PassthroughSubject
    var onPlaybackStateChanged: (@MainActor (Bool, UUID?) -> Void)?
    var onPlaybackTimeChanged: (@MainActor (TimeInterval, TimeInterval) -> Void)?
    var onSongFinished: (@MainActor (UUID) -> Void)?
    var onRemotePlayPause: (@MainActor () -> Void)?
    var onRemoteNext: (@MainActor () -> Void)?
    var onRemotePrevious: (@MainActor () -> Void)?

    // Thread-safe state management
    private let stateLock = NSLock()
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?

    // Audio Engine para ecualizador
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private let eq: AVAudioUnitEQ

    // State flags con sincronización
    private var useAudioEngine = true
    private var isFirstConnection = true
    private var currentScheduleID = UUID()
    private var wasPlayingBeforeInterruption = false
    private var seekOffset: TimeInterval = 0

    // Swift 6: Optimización de memoria - liberar recursos cuando no se reproduce
    private var resourceCleanupTimer: Timer?

    override init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()

        self.eq = AVAudioUnitEQ(numberOfBands: 6)

        super.init()
        setupAudioSession()
        setupAudioEngine()
        setupRemoteCommandCenter()
        setupInterruptionHandling()
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // CRÍTICO: Configurar la categoría para permitir reproducción en background
            // y mostrar controles en el lock screen
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: []
            )

            // Activar la sesión de audio
            try audioSession.setActive(true)
        } catch {
            // Error al configurar la sesión de audio
        }
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)

        let frequencies: [Float] = [60, 150, 400, 1000, 2400, 15000]
        for (index, frequency) in frequencies.enumerated() where index < eq.bands.count {
            eq.bands[index].filterType = .parametric
            eq.bands[index].frequency = frequency
            eq.bands[index].bandwidth = 1.0
            eq.bands[index].gain = 0.0
            eq.bands[index].bypass = false
        }

    }

    func play(songID: UUID, url: URL) {
        if currentlyPlayingID == songID {
            if !playerNode.isPlaying {
                playerNode.play()
                if !audioEngine.isRunning {
                    try? audioEngine.start()
                }
                startPlaybackTimer()

                // Notificar inmediatamente sin delay para UI responsive
                Task { @MainActor in
                    self.onPlaybackStateChanged?(true, self.currentlyPlayingID)
                }
            }
        } else {
            do {
                audioFile = try AVAudioFile(forReading: url)

                guard let audioFile = audioFile else {
                    return
                }

                let fileFormat = audioFile.processingFormat

                if !isFirstConnection {
                    playerNode.reset()

                    if audioEngine.isRunning {
                        audioEngine.stop()
                    }

                    audioEngine.disconnectNodeInput(playerNode)
                    audioEngine.disconnectNodeInput(eq)
                } else {
                    isFirstConnection = false
                }

                audioEngine.connect(playerNode, to: eq, format: fileFormat)
                audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: fileFormat)

                audioEngine.prepare()

                let scheduleID = UUID()
                self.currentScheduleID = scheduleID

                playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self = self else {
                            return
                        }

                        guard self.currentScheduleID == scheduleID else {
                            return
                        }

                        guard let currentID = self.currentlyPlayingID else {
                            return
                        }

                        self.playbackTimer?.invalidate()
                        self.playbackTimer = nil

                        self.onSongFinished?(currentID)
                    }
                }

                if !audioEngine.isRunning {
                    try audioEngine.start()
                }

                playerNode.play()

                self.currentlyPlayingID = songID
                self.seekOffset = 0 // Reset del offset al reproducir una nueva canción
                startPlaybackTimer()

                // Notificar inmediatamente sin delay para UI responsive
                Task { @MainActor in
                    self.onPlaybackStateChanged?(true, songID)
                }
            } catch {
                Task { @MainActor in
                    self.onPlaybackStateChanged?(false, nil)
                }
            }
        }
    }

    func pause() {
        playerNode.pause()
        playbackTimer?.invalidate()
        Task { @MainActor in
            self.onPlaybackStateChanged?(false, self.currentlyPlayingID)
        }
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        playbackTimer?.invalidate()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil
        Task { @MainActor in
            self.onPlaybackStateChanged?(false, oldID)
        }
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else {
            return
        }

        let wasPlaying = playerNode.isPlaying
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)

        // Detener el nodo y el timer actual
        playerNode.stop()
        playbackTimer?.invalidate()

        if startFrame < audioFile.length {
            let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

            // Actualizar el offset de seek
            self.seekOffset = time

            // Generar nuevo scheduleID para este seek
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

                    // Validar que este completion corresponde al seek actual
                    guard self.currentScheduleID == scheduleID else {
                        // Ignorar completions de seeks antiguos
                        return
                    }

                    guard let currentID = self.currentlyPlayingID else { return }

                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil

                    self.onSongFinished?(currentID)
                }
            }

            // Enviar inmediatamente el nuevo tiempo
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            Task { @MainActor in
                self.onPlaybackTimeChanged?(time, duration)
            }

            // Solo reanudar si estaba reproduciendo
            if wasPlaying {
                playerNode.play()
                startPlaybackTimer()
            }
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime),
                  let audioFile = self.audioFile else {
                return
            }

            // Calcular el tiempo desde que el nodo comenzó a reproducir + el offset del seek
            let nodePlaybackTime = Double(playerTime.sampleTime) / playerTime.sampleRate
            let currentTime = nodePlaybackTime + self.seekOffset
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            Task { @MainActor in
                self.onPlaybackTimeChanged?(currentTime, duration)
            }
        }
    }

    // MARK: - Equalizer

    /// Implementación del protocolo AudioPlayerProtocol
    func updateEqualizer(bands: [Float]) {
        for (index, gain) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].gain = gain
        }
    }

    /// Método legacy para compatibilidad con código existente
    func applyEqualizerSettings(_ bands: [EqualizerBand]) {
        for (index, band) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].gain = Float(band.gain)
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let finishedSongID = currentlyPlayingID else { return }
        currentlyPlayingID = nil
        Task { @MainActor in
            self.onPlaybackStateChanged?(false, finishedSongID)
            self.onSongFinished?(finishedSongID)
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

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if playerNode.isPlaying {
                wasPlayingBeforeInterruption = true
                pause()
            }

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, let songID = self.currentlyPlayingID else { return }

                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        // Error al reactivar la sesión
                    }

                    self.playerNode.play()
                    if !self.audioEngine.isRunning {
                        try? self.audioEngine.start()
                    }
                    self.startPlaybackTimer()
                    Task { @MainActor in
                        self.onPlaybackStateChanged?(true, songID)
                    }
                    self.wasPlayingBeforeInterruption = false
                }
            } else {
                wasPlayingBeforeInterruption = false
            }

        @unknown default:
            break
        }
    }

    deinit {
        // Limpiar recursos de audio
        playbackTimer?.invalidate()
        playbackTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Remover observers
        NotificationCenter.default.removeObserver(self)

        // Limpiar callbacks para evitar retain cycles
        onPlaybackStateChanged = nil
        onPlaybackTimeChanged = nil
        onSongFinished = nil
        onRemotePlayPause = nil
        onRemoteNext = nil
        onRemotePrevious = nil
    }

    // MARK: - Now Playing Info & Remote Commands
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onRemotePlayPause?()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onRemotePlayPause?()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onRemoteNext?()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onRemotePrevious?()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    func updateNowPlayingInfo(title: String, artist: String, album: String?, duration: TimeInterval, currentTime: TimeInterval, artwork: Data?) {
        // CRÍTICO: Crear un nuevo diccionario cada vez para forzar la actualización
        var nowPlayingInfo = [String: Any]()

        // Información básica - siempre presente
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist

        if let album = album, !album.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        // Duración total de la canción
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)

        // Tiempo actual de reproducción
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime)

        // Velocidad de reproducción (1.0 = reproduciendo, 0.0 = pausado)
        let playbackRate = playerNode.isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: playbackRate)

        // Artwork (cover art)
        if let artworkData = artwork, let image = UIImage(data: artworkData) {
            let artworkImage = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkImage
        }

        // CRÍTICO: Asignar al Now Playing Info Center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
