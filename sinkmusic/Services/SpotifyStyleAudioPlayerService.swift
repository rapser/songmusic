//
//  SpotifyStyleAudioPlayerService.swift
//  sinkmusic
//
//  Servicio de audio con calidad estilo Spotify Premium
//  Combina el mejor procesamiento para archivos AAC/M4A locales
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Servicio de audio con procesamiento completo estilo Spotify
/// - Stereo widening real (Mid-Side processing)
/// - EQ optimizado (graves potentes + agudos brillantes)
/// - Compresión dinámica
/// - Limitación de picos
final class SpotifyStyleAudioPlayerService: NSObject, AudioPlayerProtocol {

    // MARK: - Publishers

    var onPlaybackStateChanged = PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never>()
    var onPlaybackTimeChanged = PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never>()
    var onSongFinished = PassthroughSubject<UUID, Never>()

    // Remote commands
    var onRemotePlayPause = PassthroughSubject<Void, Never>()
    var onRemoteNext = PassthroughSubject<Void, Never>()
    var onRemotePrevious = PassthroughSubject<Void, Never>()

    // MARK: - Properties

    private var audioEngine: StereoProcessingEngine
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?
    private var currentScheduleID = UUID()
    private var wasPlayingBeforeInterruption = false

    // MARK: - Audio Quality Settings

    /// Presets de calidad
    enum QualityPreset {
        case standard    // Procesamiento básico
        case spotify     // Estilo Spotify (recomendado)
        case audiophile  // Máxima calidad (más CPU)

        var stereoWidth: Float {
            switch self {
            case .standard: return 0.1
            case .spotify: return 0.15  // Muy sutil - todos los instrumentos en ambos lados
            case .audiophile: return 0.25
            }
        }

        var compressionIntensity: Float {
            switch self {
            case .standard: return 0.2
            case .spotify: return 0.3  // Reducido para más rango dinámico
            case .audiophile: return 0.25
            }
        }
    }

    private var currentPreset: QualityPreset = .spotify

    // MARK: - Initialization

    override init() {
        self.audioEngine = StereoProcessingEngine()
        super.init()

        setupAudioSession()
        applyQualityPreset(.spotify)
        setupRemoteCommandCenter()
        setupInterruptionHandling()
        setupRouteChangeHandling()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            // Configuración óptima para música
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers] // Permitir mezcla con otras apps
            )

            // Activar sesión
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Configurar para audio de alta calidad
            if session.isOtherAudioPlaying {
                // Si hay otro audio, reducir calidad temporalmente
                try session.setPreferredSampleRate(44100)
            } else {
                // Calidad máxima
                try session.setPreferredSampleRate(48000)
            }

            // Buffer pequeño para baja latencia
            try session.setPreferredIOBufferDuration(0.005) // 5ms

        } catch {
            print("Error configurando AVAudioSession: \(error)")
        }
    }

    // MARK: - Quality Presets

    /// Aplica un preset de calidad
    func applyQualityPreset(_ preset: QualityPreset) {
        currentPreset = preset
        audioEngine.setStereoWidth(preset.stereoWidth)
        audioEngine.setCompressionIntensity(preset.compressionIntensity)
        audioEngine.setBassBoostEnabled(true)
        audioEngine.setTrebleBoostEnabled(true)
        audioEngine.setStereoProcessingEnabled(true)
    }

    // MARK: - Playback

    func play(songID: UUID, url: URL) {
        let playerNode = audioEngine.getPlayerNode()

        // Si es la misma canción, reanudar
        if currentlyPlayingID == songID {
            if !playerNode.isPlaying {
                playerNode.play()
                try? audioEngine.start()

                if let audioFile = audioFile {
                    startPlaybackTimer(with: audioFile)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.onPlaybackStateChanged.send((isPlaying: true, songID: songID))
                }
            }
            return
        }

        // Nueva canción
        do {
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile = audioFile else {
                onPlaybackStateChanged.send((isPlaying: false, songID: nil))
                return
            }

            let fileFormat = audioFile.processingFormat

            // Verificar que sea estéreo
            if fileFormat.channelCount < 2 {
                print("⚠️ Advertencia: El archivo no es estéreo (canales: \(fileFormat.channelCount))")
            }

            // Conectar nodos con formato estéreo
            try audioEngine.connectNodes(with: fileFormat)

            // Programar reproducción
            let scheduleID = UUID()
            self.currentScheduleID = scheduleID

            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self,
                          self.currentScheduleID == scheduleID,
                          let currentID = self.currentlyPlayingID else {
                        return
                    }

                    self.stopPlaybackTimer()
                    self.onSongFinished.send(currentID)
                }
            }

            // Iniciar reproducción
            try audioEngine.start()
            playerNode.play()

            // Actualizar estado
            self.currentlyPlayingID = songID
            startPlaybackTimer(with: audioFile)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onPlaybackStateChanged.send((isPlaying: true, songID: songID))
            }

        } catch {
            print("Error reproduciendo: \(error)")
            onPlaybackStateChanged.send((isPlaying: false, songID: nil))
        }
    }

    func pause() {
        let playerNode = audioEngine.getPlayerNode()
        playerNode.pause()
        stopPlaybackTimer()
        onPlaybackStateChanged.send((isPlaying: false, songID: currentlyPlayingID))
    }

    func stop() {
        let playerNode = audioEngine.getPlayerNode()
        playerNode.stop()
        audioEngine.stop()

        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil

        stopPlaybackTimer()
        onPlaybackStateChanged.send((isPlaying: false, songID: oldID))
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }

        let playerNode = audioEngine.getPlayerNode()
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)

        playerNode.stop()

        if startFrame < audioFile.length {
            let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

            playerNode.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil
            ) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self,
                          let currentID = self.currentlyPlayingID else {
                        return
                    }

                    self.stopPlaybackTimer()
                    self.onSongFinished.send(currentID)
                }
            }

            playerNode.play()
        }
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer(with audioFile: AVAudioFile) {
        stopPlaybackTimer()

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let playerNode = self.audioEngine.getPlayerNode()

            guard let nodeTime = playerNode.lastRenderTime,
                  let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return
            }

            let currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            self.onPlaybackTimeChanged.send((time: currentTime, duration: duration))
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - EQ Control

    func updateEqualizer(bands: [Float]) {
        audioEngine.updateMainEqualizer(bands: bands)
    }

    // MARK: - Advanced Controls

    /// Ajusta la amplitud estéreo (0.0-1.0, recomendado: 0.5-0.8)
    func setStereoWidth(_ width: Float) {
        audioEngine.setStereoWidth(width)
    }

    /// Activa/desactiva boost de graves
    func setBassBoost(_ enabled: Bool) {
        audioEngine.setBassBoostEnabled(enabled)
    }

    /// Activa/desactiva boost de agudos
    func setTrebleBoost(_ enabled: Bool) {
        audioEngine.setTrebleBoostEnabled(enabled)
    }

    /// Ajusta intensidad de compresión (0.0-1.0)
    func setCompression(_ intensity: Float) {
        audioEngine.setCompressionIntensity(intensity)
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

        let playerNode = audioEngine.getPlayerNode()

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
                    guard let self = self,
                          let songID = self.currentlyPlayingID else {
                        return
                    }

                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        try self.audioEngine.start()
                        playerNode.play()

                        if let audioFile = self.audioFile {
                            self.startPlaybackTimer(with: audioFile)
                        }

                        self.onPlaybackStateChanged.send((isPlaying: true, songID: songID))
                        self.wasPlayingBeforeInterruption = false
                    } catch {
                        print("Error reanudando: \(error)")
                    }
                }
            } else {
                wasPlayingBeforeInterruption = false
            }

        @unknown default:
            break
        }
    }

    // MARK: - Route Change Handling

    private func setupRouteChangeHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Solo pausar cuando se desconectan los audífonos
        if reason == .oldDeviceUnavailable {
            // Verificar si era un dispositivo de salida (audífonos/AirPods)
            guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else {
                return
            }

            // Verificar si había audífonos conectados
            let wasHeadphones = previousRoute.outputs.contains { output in
                output.portType == .headphones ||
                output.portType == .bluetoothA2DP ||
                output.portType == .bluetoothHFP ||
                output.portType == .bluetoothLE
            }

            if wasHeadphones {
                print("🎧 Audífonos desconectados - pausando reproducción")
                pause()

                // Reconfigurar la sesión de audio para redirigir a los altavoces
                reconfigureAudioSessionForCurrentRoute()
            }
        } else if reason == .newDeviceAvailable {
            // Cuando se conectan nuevos audífonos, reconfigurar la ruta
            print("🎧 Nuevo dispositivo de audio conectado")
            reconfigureAudioSessionForCurrentRoute()
        }
    }

    private func reconfigureAudioSessionForCurrentRoute() {
        do {
            let session = AVAudioSession.sharedInstance()

            // Desactivar y reactivar la sesión para forzar la actualización de la ruta
            try session.setActive(false, options: .notifyOthersOnDeactivation)

            // Pequeña pausa para permitir que el sistema actualice la ruta
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                do {
                    // Reactivar con la nueva ruta de audio
                    try session.setActive(true, options: .notifyOthersOnDeactivation)

                    // Verificar la ruta actual
                    let currentRoute = session.currentRoute
                    let outputType = currentRoute.outputs.first?.portType

                    if outputType == .builtInSpeaker {
                        print("🔊 Audio redirigido a altavoces del iPhone")
                    } else if outputType == .headphones || outputType == .bluetoothA2DP {
                        print("🎧 Audio conectado a audífonos")
                    }

                    // Reiniciar el motor de audio con la nueva ruta
                    self?.restartAudioEngine()

                } catch {
                    print("Error reactivando sesión de audio: \(error)")
                }
            }
        } catch {
            print("Error reconfigurando sesión de audio: \(error)")
        }
    }

    private func restartAudioEngine() {
        guard let audioFile = audioFile else { return }

        do {
            // Detener el motor actual
            audioEngine.stop()

            // Reconectar los nodos con el formato correcto
            try audioEngine.connectNodes(with: audioFile.processingFormat)

            // Solo reiniciar si había una canción cargada
            if currentlyPlayingID != nil {
                try audioEngine.start()
                print("✅ Motor de audio reiniciado con nueva ruta")
            }
        } catch {
            print("Error reiniciando motor de audio: \(error)")
        }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onRemotePlayPause.send()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onRemotePlayPause.send()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onRemoteNext.send()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePrevious.send()
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

    // MARK: - Now Playing Info

    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        artwork: Data?
    ) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist

        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = audioEngine.getPlayerNode().isPlaying ? 1.0 : 0.0

        if let artworkData = artwork, let image = UIImage(data: artworkData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlaybackTimer()
    }
}
