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
final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, AudioPlayerProtocol {

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol

    // State management — aislado a @MainActor, no necesita lock
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?

    // Audio Engine: ecualizador + mixer para reproducción de alta fidelidad (estilo Tidal Hi-Fi)
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private let eq: AVAudioUnitEQ
    private let mixerNode: AVAudioMixerNode

    // State flags con sincronización
    private var isFirstConnection = true
    private var currentScheduleID = UUID()
    private var wasPlayingBeforeInterruption = false
    private var seekOffset: TimeInterval = 0

    // MARK: - Now Playing

    /// Última posición conocida. Mientras el nodo está pausado `playerTime(forNodeTime:)`
    /// devuelve nil, así que este es el único valor válido para informar a iOS.
    private var lastKnownTime: TimeInterval = 0

    /// Metadata fija de la canción actual (título/artista/álbum/artwork/duración).
    /// Se construye una vez por canción; los refrescos de tiempo solo mutan este diccionario
    /// en lugar de reconstruirlo, evitando re-decodificar el artwork cada segundo.
    private var nowPlayingBase: [String: Any] = [:]

    /// Artwork ya convertido a `MPMediaItemArtwork`, junto al `Data` del que salió,
    /// para reutilizarlo mientras no cambie la canción.
    private var cachedArtworkData: Data?

    private var lastNowPlayingPush: CFTimeInterval = 0

    /// Estado real de reproducción — **fuente única de verdad de toda la app**.
    /// Ninguna otra capa debe mantener su propio flag: el motor de audio es el único
    /// que sabe si suena o no, y cachearlo en otra capa es lo que desincronizaba el
    /// widget nativo con el player interno.
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

    /// Carga y arranca una canción desde `startTime`.
    ///
    /// Siempre (re)programa el archivo — para continuar una canción ya cargada usa `resume()`,
    /// que no reinicia la posición ni vuelve a contar la reproducción.
    func play(songID: UUID, url: URL, startTime: TimeInterval = 0) {
        // Asegurar sesión activa para que Lock Screen y Control Center muestren Now Playing
        try? AVAudioSession.sharedInstance().setActive(true)

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
            let outFormat = stereoFormat ?? fileFormat

            if isFirstConnection {
                // La cadena se arma una sola vez; luego solo cambiamos la pista programada.
                audioEngine.connect(playerNode, to: eq, format: fileFormat)
                audioEngine.connect(eq, to: mixerNode, format: fileFormat)
                audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outFormat)
                isFirstConnection = false
            } else {
                playerNode.stop()
            }

            // Cadena Hi-Fi: playerNode → eq (bypass) → mixerNode (estéreo) → mainMixerNode
            // Sin efectos intermedios: señal lo más pura posible, igual que Tidal.

            // Pan neutro: canal izquierdo y derecho con igual peso
            playerNode.pan = 0

            audioEngine.prepare()

            let scheduleID = UUID()
            self.currentScheduleID = scheduleID

            let onCompletion: @Sendable () -> Void = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard self.currentScheduleID == scheduleID else { return }
                    guard let currentID = self.currentlyPlayingID else { return }

                    self.handlePlaybackCompleted()
                    self.eventBus.emit(.songFinished(currentID))
                }
            }

            // Una sola programación: si hay posición inicial se programa el segmento
            // directamente, en vez de programar el archivo entero y hacer seek después.
            let sampleRate = fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(startTime * sampleRate)

            if startTime > 0 && startFrame < audioFile.length {
                playerNode.scheduleSegment(
                    audioFile,
                    startingFrame: startFrame,
                    frameCount: AVAudioFrameCount(audioFile.length - startFrame),
                    at: nil,
                    completionHandler: onCompletion
                )
                self.seekOffset = startTime
                self.lastKnownTime = startTime
            } else {
                playerNode.scheduleFile(audioFile, at: nil, completionHandler: onCompletion)
                self.seekOffset = 0
                self.lastKnownTime = 0
            }

            // El engine debe estar corriendo ANTES de que el nodo reproduzca.
            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            playerNode.play()

            self.currentlyPlayingID = songID
            startPlaybackTimer()
            pushNowPlaying(elapsed: lastKnownTime, isPlaying: true)
            eventBus.emit(.stateChanged(isPlaying: true, songID: songID))
        } catch {
            clearNowPlaying()
            eventBus.emit(.stateChanged(isPlaying: false, songID: nil))
        }
    }

    /// Continúa la canción ya cargada sin reprogramarla.
    ///
    /// - Returns: `true` si había una pista en el motor y se reanudó. `false` significa que no
    ///   hay nada cargado (arranque en frío) y el llamador debe hacer un `play` real.
    @discardableResult
    func resume() -> Bool {
        guard currentlyPlayingID != nil, audioFile != nil else { return false }

        // Idempotente: un `playCommand` redundante es justo el síntoma de una desincronización,
        // así que lo honramos re-afirmándole a iOS la verdad en vez de ignorarlo.
        guard !playerNode.isPlaying else {
            pushNowPlaying(elapsed: currentPlaybackTime(), isPlaying: true)
            return true
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        playerNode.play()
        startPlaybackTimer()

        pushNowPlaying(elapsed: lastKnownTime, isPlaying: true)
        eventBus.emit(.stateChanged(isPlaying: true, songID: currentlyPlayingID))
        return true
    }

    func pause() {
        // Idempotente por el mismo motivo que `resume()`: un `pauseCommand` que llega
        // estando ya en pausa no debe arrancar nada, solo re-afirmar el estado.
        guard playerNode.isPlaying else {
            pushNowPlaying(elapsed: lastKnownTime, isPlaying: false)
            return
        }

        // Capturar la posición ANTES de pausar: después el nodo ya no la reporta.
        lastKnownTime = currentPlaybackTime()

        playerNode.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil

        pushNowPlaying(elapsed: lastKnownTime, isPlaying: false)
        eventBus.emit(.stateChanged(isPlaying: false, songID: currentlyPlayingID))
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        // Invalida cualquier completion en vuelo de la pista que acabamos de detener.
        currentScheduleID = UUID()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil
        seekOffset = 0
        lastKnownTime = 0
        clearNowPlaying()
        eventBus.emit(.stateChanged(isPlaying: false, songID: oldID))
    }

    /// La canción llegó a su fin por sí sola.
    ///
    /// `AVAudioPlayerNode.isPlaying` sigue devolviendo `true` cuando el buffer se agota — solo
    /// baja con un `pause()`/`stop()` explícito. Como el toggle ahora consulta al motor, sin
    /// esto una canción terminada respondería "reproduciendo" y el siguiente toque pausaría
    /// en lugar de avanzar.
    private func handlePlaybackCompleted() {
        playerNode.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        lastKnownTime = fileDuration()
        pushNowPlaying(elapsed: lastKnownTime, isPlaying: false)
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
        playbackTimer = nil

        guard startFrame < audioFile.length else {
            // Seek más allá del final: tratarlo como fin de pista en vez de dejar el nodo
            // parado en silencio sin avisar a nadie.
            guard let currentID = currentlyPlayingID else { return }
            handlePlaybackCompleted()
            eventBus.emit(.songFinished(currentID))
            return
        }

        let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

        self.seekOffset = time
        self.lastKnownTime = time

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

                self.handlePlaybackCompleted()
                self.eventBus.emit(.songFinished(currentID))
            }
        }

        let duration = fileDuration()
        eventBus.emit(.timeUpdated(current: time, duration: duration))

        if wasPlaying {
            playerNode.play()
            startPlaybackTimer()
        }

        pushNowPlaying(elapsed: time, isPlaying: wasPlaying)
    }

    /// Posición actual real del nodo. Mientras está pausado devuelve la última conocida,
    /// porque `playerTime(forNodeTime:)` deja de reportar.
    private func currentPlaybackTime() -> TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid || nodeTime.isHostTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return lastKnownTime
        }
        let nodePlaybackTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        lastKnownTime = nodePlaybackTime + seekOffset
        return lastKnownTime
    }

    /// Duración real del archivo cargado. Más fiable que la metadata de la canción,
    /// que puede venir vacía.
    private func fileDuration() -> TimeInterval {
        guard let audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.processingFormat.sampleRate
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
                      self.audioFile != nil else {
                    return
                }
                let nodePlaybackTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                let currentTime = nodePlaybackTime + self.seekOffset
                let duration = self.fileDuration()
                self.lastKnownTime = currentTime
                self.eventBus.emit(.timeUpdated(current: currentTime, duration: duration))

                // Refresco periódico del widget nativo (1 Hz). Vive aquí, en el dueño del
                // estado, y no en el ViewModel: solo muta un diccionario ya construido.
                let now = CACurrentMediaTime()
                if now - self.lastNowPlayingPush >= 1.0 {
                    self.pushNowPlaying(elapsed: currentTime, isPlaying: true)
                }
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

    // MARK: - Interruption Handling

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

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
                // Reutiliza `resume()` para heredar el orden correcto del motor y el
                // refresco de Now Playing, en vez de repetir la secuencia a mano.
                if !self.resume() {
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

        // Intenciones explícitas: iOS envía play o pause según el estado que él cree que
        // tenemos. Traducirlas a un toggle hacía que un `pauseCommand` acabara reproduciendo
        // en cuanto los dos estados se desfasaban, y el espejo ya no se recuperaba.
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.play))
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventBus.emit(.remoteCommand(.pause))
            }
            return .success
        }

        // Botón central de los AirPods / auriculares: aquí sí es un alternar de verdad.
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
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
                // Solo emitir: el evento ya rutea el seek de vuelta hasta aquí vía
                // PlayerViewModel → PlayerUseCases → repositorio. Llamarlo además de forma
                // directa provocaba dos `stop()` + `scheduleSegment` por cada arrastre.
                self?.eventBus.emit(.remoteCommand(.seek(position)))
            }
            return .success
        }
    }

    /// Fija la metadata de la canción actual. Se llama una vez por canción, no en cada tick.
    func setNowPlayingMetadata(title: String, artist: String, album: String?, duration: TimeInterval, artwork: Data?) {
        var info = [String: Any]()

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist

        if let album = album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        // Evitar NaN/infinitos: el sistema puede hacer INVOP al asignar nowPlayingInfo
        let safeDuration = duration.isFinite && duration >= 0 ? duration : 0
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: safeDuration)
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // Reconstruir el artwork solo si cambió: convertirlo es caro y antes se rehacía
        // en cada refresco de tiempo.
        if let artworkData = artwork {
            if artworkData != cachedArtworkData || nowPlayingBase[MPMediaItemPropertyArtwork] == nil {
                if let image = UIImage(data: artworkData) {
                    // El sistema invoca el closure desde otro hilo: debe ser @Sendable y solo capturar Sendable (Data).
                    let artworkImage = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in
                        UIImage(data: artworkData) ?? UIImage()
                    }
                    info[MPMediaItemPropertyArtwork] = artworkImage
                    cachedArtworkData = artworkData
                }
            } else if let existing = nowPlayingBase[MPMediaItemPropertyArtwork] {
                info[MPMediaItemPropertyArtwork] = existing
            }
        } else {
            cachedArtworkData = nil
        }

        nowPlayingBase = info
        pushNowPlaying(elapsed: currentPlaybackTime(), isPlaying: playerNode.isPlaying)
    }

    /// Refresca solo el tiempo transcurrido (y la duración si se conoce).
    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?) {
        if let duration, duration.isFinite, duration > 0 {
            nowPlayingBase[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
        }
        pushNowPlaying(elapsed: elapsed, isPlaying: playerNode.isPlaying)
    }

    /// Único punto que escribe en `MPNowPlayingInfoCenter`.
    ///
    /// El orden importa: primero `nowPlayingInfo` (para que iOS tenga el tiempo fresco) y
    /// después `playbackState`. Al revés, iOS extrapola un frame desde el valor anterior.
    private func pushNowPlaying(elapsed: TimeInterval, isPlaying: Bool) {
        var info = nowPlayingBase

        let safeElapsed = elapsed.isFinite && elapsed >= 0 ? elapsed : 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: safeElapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: isPlaying ? 1.0 : 0.0)
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: 1.0)

        // La duración real del archivo es más fiable que la metadata de la canción.
        let realDuration = fileDuration()
        if realDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: realDuration)
            nowPlayingBase[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: realDuration)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        lastNowPlayingPush = CACurrentMediaTime()
    }

    private func clearNowPlaying() {
        nowPlayingBase = [:]
        cachedArtworkData = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
