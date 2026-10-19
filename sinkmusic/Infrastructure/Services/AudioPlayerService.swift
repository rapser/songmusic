//
//  AudioPlayerService.swift
//  sinkmusic
//
//  Refactored to emit events via EventBus (Clean Architecture)
//  No callbacks - All events via EventBus
//

import Foundation
import AVFoundation
import QuartzCore

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
    private var seekOffset: TimeInterval = 0

    /// Reloj autoritativo de la reproducción — **la única fuente de tiempo de la app**.
    ///
    /// Traduce los frames renderizados por el nodo a una posición acotada a la duración real
    /// del archivo, y detecta por sí mismo tanto el fin de pista como un motor atascado. Ni
    /// este servicio ni ninguna capa superior llevan su propio contador: todos leen de aquí.
    private let clock = PlaybackClock()

    /// Reacción a interrupciones de `AVAudioSession` (llamadas, Siri, otra app).
    private let interruptions: AudioInterruptionObserver

    /// Tokens de `AVAudioEngineConfigurationChange` y `AVAudioSession.routeChange`. No son
    /// Sendable y `removeObserver` es seguro desde cualquier hilo, así que se acceden sin el
    /// chequeo de aislamiento de actor.
    private nonisolated(unsafe) var configChangeToken: NSObjectProtocol?
    private nonisolated(unsafe) var routeChangeToken: NSObjectProtocol?

    // MARK: - Now Playing

    /// Pantalla de bloqueo / Centro de Control (metadata + comandos remotos).
    private let nowPlaying: NowPlayingCenter

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
        self.nowPlaying = NowPlayingCenter(eventBus: eventBus)
        self.interruptions = AudioInterruptionObserver(eventBus: eventBus)

        super.init()
        setupAudioSession()
        setupAudioEngine()
        observeConfigurationChange()
        nowPlaying.setupRemoteCommands()
        interruptions.start(delegate: self)
    }

    deinit {
        if let configChangeToken {
            NotificationCenter.default.removeObserver(configChangeToken)
        }
        if let routeChangeToken {
            NotificationCenter.default.removeObserver(routeChangeToken)
        }
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

            // Fijar un buffer de IO estable (~20 ms). Sin esto, un componente externo
            // (p. ej. el PHPicker al abrir su UI) puede renegociar el tamaño de buffer
            // bajo el engine que está sonando → crujido.
            try? audioSession.setPreferredIOBufferDuration(0.02)

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

    // MARK: - Configuration Change

    /// `AVAudioEngine` **se detiene solo** cuando cambia el formato de salida del hardware:
    /// cambio de ruta, o **otro proceso que renegocia la `AVAudioSession` compartida** — el
    /// `PHPicker` al abrir su UI, y el proceso del teclado al aparecer por primera vez.
    /// Sin manejarlo, el engine queda parado o desajustado → crujido / silencio hasta que
    /// algo lo reinicia. Aquí se rehace el grafo con el formato nuevo y se re-agenda la
    /// pista desde la posición actual. Se escucha también `routeChange` porque no todas las
    /// perturbaciones emiten `AVAudioEngineConfigurationChange`.
    private func observeConfigurationChange() {
        configChangeToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recoverEngineIfStopped()
            }
        }
        routeChangeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            // `Notification` no es Sendable: se extrae el valor primitivo antes del hop.
            let reasonRaw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonRaw: reasonRaw)
            }
        }
    }

    private func handleRouteChange(reasonRaw: UInt) {
        if AVAudioSession.RouteChangeReason(rawValue: reasonRaw) == .oldDeviceUnavailable {
            // El dispositivo de salida se retiró (p. ej. auriculares): iOS detiene el audio.
            // NO reanudar en el altavoz — solo dejar el estado consistente y en pausa.
            guard playbackTimer != nil else { return }
            let progress = syncClockWithEngine()
            stopPlaybackTimer()
            pushNowPlaying(progress, isPlaying: false)
            eventBus.emit(.stateChanged(isPlaying: false, songID: currentlyPlayingID))
            return
        }
        recoverEngineIfStopped()
    }

    /// Si el engine se detuvo (perturbación de sesión / cambio de formato) pero seguimos con
    /// una pista cargada, rehace el grafo y re-agenda desde la posición actual. También cubre
    /// el caso en que el engine sigue corriendo pero el nodo quedó parado con sus buffers
    /// descartados. Ante una perturbación benigna (engine y nodo intactos) no toca nada —
    /// evita meter un glitch propio.
    private func recoverEngineIfStopped() {
        guard let audioFile, let songID = currentlyPlayingID, audioFile.length > 0 else { return }

        // El `playbackTimer` solo vive mientras suena (se invalida en pause/stop/fin de pista),
        // así que es la señal fiable de "estábamos reproduciendo" ahora que el nodo ya no reporta.
        let wasPlaying = playbackTimer != nil

        // Una reconfiguración puede dejar el engine corriendo pero haber parado el nodo y
        // descartado sus buffers. Si creíamos estar sonando y el nodo ya no lo está, también
        // hay que rehacer el grafo: si no, el engine se queda renderizando silencio.
        guard !audioEngine.isRunning || (wasPlaying && !playerNode.isPlaying) else { return }

        rebuildGraphAndReschedule(audioFile: audioFile, songID: songID, resumePlaying: wasPlaying)
    }

    /// Rehace el grafo del engine y reprograma la pista desde la posición del reloj.
    ///
    /// Es el único camino de recuperación: lo usan tanto las notificaciones del sistema
    /// (cambio de configuración o de ruta) como el detector de atasco del reloj.
    private func rebuildGraphAndReschedule(audioFile: AVAudioFile, songID: UUID, resumePlaying: Bool) {
        let duration = fileDuration()
        let resumeAt = clock.progress.elapsed

        // Si la posición ya estaba en el final, reprogramar el último frame suelto solo
        // produciría un "fin" espurio: se cierra como fin de pista normal.
        if duration > 0, resumeAt >= duration - PlaybackClock.endOfTrackTolerance {
            finishTrack()
            return
        }

        playerNode.stop()

        let fileFormat = audioFile.processingFormat
        let outFormat = AVAudioFormat(standardFormatWithSampleRate: fileFormat.sampleRate, channels: 2) ?? fileFormat
        audioEngine.connect(playerNode, to: eq, format: fileFormat)
        audioEngine.connect(eq, to: mixerNode, format: fileFormat)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outFormat)
        audioEngine.prepare()

        let sampleRate = fileFormat.sampleRate
        let startFrame = min(max(0, AVAudioFramePosition(resumeAt * sampleRate)), audioFile.length - 1)

        let scheduleID = newSchedule()
        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(audioFile.length - startFrame),
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: makeCompletionHandler(scheduleID)
        )
        seekOffset = Double(startFrame) / sampleRate
        clock.load(duration: duration, startingAt: seekOffset, at: CACurrentMediaTime())

        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            if resumePlaying {
                playerNode.play()
                clock.resumed(at: CACurrentMediaTime())
                startPlaybackTimer()
            }
            pushNowPlaying(clock.progress, isPlaying: resumePlaying)
        } catch {
            stopPlaybackTimer()
            eventBus.emit(.stateChanged(isPlaying: false, songID: songID))
        }
    }

    /// Abre una programación nueva, invalidando los completion handlers en vuelo de la
    /// anterior. La marca de fin de pista vive en el reloj y la limpia quien lo reposiciona.
    private func newSchedule() -> UUID {
        let scheduleID = UUID()
        currentScheduleID = scheduleID
        return scheduleID
    }

    /// Completion handler de una programación de reproducción.
    ///
    /// Se pide `.dataPlayedBack` en lugar del tipo por defecto (`.dataConsumed`): este último
    /// se dispara cuando el nodo termina de *leer* el archivo, no cuando termina de sonar, y
    /// cortaba la pista un buffer antes del final.
    private func makeCompletionHandler(_ scheduleID: UUID) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentScheduleID == scheduleID else { return }
                self.finishTrack()
            }
        }
    }

    /// Punto único de "la pista llegó al final".
    ///
    /// Idempotente: el final puede llegar por el aviso del motor o porque el reloj vea la
    /// posición pasada de la duración, y solo el primero en llegar emite. La marca la lleva
    /// el reloj (`hasReachedEnd`), no un flag paralelo.
    private func finishTrack() {
        guard !clock.hasReachedEnd, let songID = currentlyPlayingID else { return }
        handlePlaybackCompleted()
        // El espejo de UI vive de este evento: sin él el ViewModel sigue creyendo que suena,
        // el mini player queda con el icono de pausa y un `repeatOne` acaba haciendo `seek(0)`
        // sobre un nodo pausado (silencio).
        eventBus.emit(.stateChanged(isPlaying: false, songID: songID))
        eventBus.emit(.songFinished(songID))
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

            let onCompletion = makeCompletionHandler(newSchedule())

            // Una sola programación: si hay posición inicial se programa el segmento
            // directamente, en vez de programar el archivo entero y hacer seek después.
            // Una posición restaurada que ya está en el final (la canción terminó justo antes
            // de cerrar la app) se ignora: programar el último sobrante sonaría a nada y
            // saltaría de inmediato a la siguiente.
            let sampleRate = fileFormat.sampleRate
            let trackDuration = Double(audioFile.length) / sampleRate
            let resumeAt = startTime > 0 && startTime < trackDuration - PlaybackClock.endOfTrackTolerance ? startTime : 0
            let startFrame = AVAudioFramePosition(resumeAt * sampleRate)

            if resumeAt > 0 {
                playerNode.scheduleSegment(
                    audioFile,
                    startingFrame: startFrame,
                    frameCount: AVAudioFrameCount(audioFile.length - startFrame),
                    at: nil,
                    completionCallbackType: .dataPlayedBack,
                    completionHandler: onCompletion
                )
                self.seekOffset = resumeAt
            } else {
                playerNode.scheduleFile(
                    audioFile,
                    at: nil,
                    completionCallbackType: .dataPlayedBack,
                    completionHandler: onCompletion
                )
                self.seekOffset = 0
            }

            clock.load(duration: trackDuration, startingAt: resumeAt, at: CACurrentMediaTime())

            // El engine debe estar corriendo ANTES de que el nodo reproduzca.
            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            playerNode.play()
            clock.resumed(at: CACurrentMediaTime())

            self.currentlyPlayingID = songID
            startPlaybackTimer()
            pushNowPlaying(clock.progress, isPlaying: true)
            eventBus.emit(.stateChanged(isPlaying: true, songID: songID))
        } catch {
            clock.reset()
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

        // La pista ya terminó: el nodo no tiene nada programado. Un `play()` ahí solo
        // renderizaría silencio con el contador corriendo, así que se pide un `play` real.
        guard !clock.hasReachedEnd else { return false }

        // Idempotente: un `playCommand` redundante es justo el síntoma de una desincronización,
        // así que lo honramos re-afirmándole a iOS la verdad en vez de ignorarlo.
        guard !playerNode.isPlaying else {
            pushNowPlaying(syncClockWithEngine(), isPlaying: true)
            return true
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        playerNode.play()
        clock.resumed(at: CACurrentMediaTime())
        startPlaybackTimer()

        pushNowPlaying(clock.progress, isPlaying: true)
        eventBus.emit(.stateChanged(isPlaying: true, songID: currentlyPlayingID))
        return true
    }

    func pause() {
        // Idempotente por el mismo motivo que `resume()`: un `pauseCommand` que llega
        // estando ya en pausa no debe arrancar nada, solo re-afirmar el estado.
        guard playerNode.isPlaying else {
            pushNowPlaying(clock.progress, isPlaying: false)
            return
        }

        // Capturar la posición ANTES de pausar: después el nodo ya no la reporta.
        let progress = syncClockWithEngine()

        playerNode.pause()
        stopPlaybackTimer()

        pushNowPlaying(progress, isPlaying: false)
        eventBus.emit(.stateChanged(isPlaying: false, songID: currentlyPlayingID))
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        stopPlaybackTimer()
        // Invalida cualquier completion en vuelo de la pista que acabamos de detener.
        _ = newSchedule()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil
        seekOffset = 0
        clock.reset()
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
        stopPlaybackTimer()
        clock.markReachedEnd()
        pushNowPlaying(clock.progress, isPlaying: false)
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else {
            return
        }

        let wasPlaying = playerNode.isPlaying
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)

        playerNode.stop()
        stopPlaybackTimer()

        guard startFrame < audioFile.length else {
            // Seek más allá del final: tratarlo como fin de pista en vez de dejar el nodo
            // parado en silencio sin avisar a nadie.
            finishTrack()
            return
        }

        let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

        self.seekOffset = time
        clock.seek(to: time, at: CACurrentMediaTime())

        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: makeCompletionHandler(newSchedule())
        )

        eventBus.emit(.timeUpdated(clock.progress))

        if wasPlaying {
            playerNode.play()
            clock.resumed(at: CACurrentMediaTime())
            startPlaybackTimer()
        }

        pushNowPlaying(clock.progress, isPlaying: wasPlaying)
    }

    /// Posición cruda del nodo, **sin acotar**. `nil` mientras el nodo no reporta tiempo
    /// (pausado o aún sin arrancar).
    ///
    /// Un `AVAudioPlayerNode` que se queda sin buffers programados no se detiene: sigue
    /// "reproduciendo" silencio y este valor sigue creciendo sin límite. Por eso lo crudo solo
    /// lo ve el `PlaybackClock`, que es quien lo acota y quien detecta esa condición.
    private func nodePlaybackTime() -> TimeInterval? {
        guard let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid || nodeTime.isHostTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        return Double(playerTime.sampleTime) / playerTime.sampleRate + seekOffset
    }

    /// Alinea el reloj con lo que reporta el nodo y devuelve la posición vigente.
    ///
    /// Para leer la posición en una transición (pausar, informar a la pantalla de bloqueo).
    /// Mientras el nodo está pausado no reporta nada y se conserva la del reloj.
    @discardableResult
    private func syncClockWithEngine() -> PlaybackProgress {
        if let raw = nodePlaybackTime() {
            clock.align(to: raw)
        }
        return clock.progress
    }

    /// Duración real del archivo cargado. Más fiable que la metadata de la canción,
    /// que puede venir vacía.
    private func fileDuration() -> TimeInterval {
        guard let audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()

        playbackTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            // El closure del Timer es @Sendable — no podemos leer propiedades @MainActor aquí.
            // Despachamos todo al MainActor donde el acceso es seguro.
            Task { @MainActor [weak self] in
                self?.tickPlaybackTime()
            }
        }

        RunLoop.current.add(playbackTimer!, forMode: .common)
    }

    /// Un tick del timer de progreso (~10 Hz). Toda la interpretación la hace el reloj;
    /// aquí solo se actúa sobre lo que concluye.
    private func tickPlaybackTime() {
        guard audioFile != nil else { return }

        switch clock.tick(rawPosition: nodePlaybackTime(), at: CACurrentMediaTime()) {
        case .progress(let progress):
            publish(progress)

        case .reachedEnd:
            // El motor nunca avisó del final. Pasa cuando iOS descarta los buffers
            // programados al reconfigurar la sesión de audio con la app en segundo plano:
            // el nodo se queda "reproduciendo" silencio y su posición se va más allá de la
            // duración. Como la posición la acota el reloj, la app y la pantalla de bloqueo
            // siguen mostrando lo mismo mientras tanto.
            finishTrack()

        case .stalled(let progress):
            // El caso inverso: el motor se paró y dejó de entregar frames, sin emitir
            // ninguna notificación de ruta ni de configuración a la que reaccionar. El reloj
            // es la única señal, y rehacer el grafo lo devuelve a sonar desde esta posición.
            publish(progress)
            recoverStalledEngine()
        }
    }

    /// Publica la posición vigente hacia la app y hacia el widget nativo. Las dos superficies
    /// leen el mismo valor del reloj: es lo que impide que se separen.
    private func publish(_ progress: PlaybackProgress) {
        eventBus.emit(.timeUpdated(progress))

        // Refresco periódico del widget nativo (~1 Hz); el throttle vive en NowPlayingCenter.
        nowPlaying.pushIfStale(progress, isPlaying: true, minInterval: 1.0)
    }

    /// El reloj detectó que el motor dejó de entregar audio: se rehace el grafo desde la
    /// última posición buena.
    private func recoverStalledEngine() {
        guard let audioFile, let songID = currentlyPlayingID, audioFile.length > 0 else { return }
        rebuildGraphAndReschedule(audioFile: audioFile, songID: songID, resumePlaying: true)
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

    /// Fija la metadata de la canción actual. Se llama una vez por canción, no en cada tick.
    func setNowPlayingMetadata(title: String, artist: String, album: String?, duration: TimeInterval, artwork: Data?) {
        nowPlaying.setMetadata(
            title: title, artist: artist, album: album, duration: duration, artwork: artwork,
            progress: syncClockWithEngine(), isPlaying: playerNode.isPlaying
        )
    }

    /// Empuja el estado a `MPNowPlayingInfoCenter` (vía `NowPlayingCenter`).
    private func pushNowPlaying(_ progress: PlaybackProgress, isPlaying: Bool) {
        nowPlaying.push(progress, isPlaying: isPlaying)
    }

    private func clearNowPlaying() {
        nowPlaying.clear()
    }
}

// MARK: - AudioInterruptionDelegate

extension AudioPlayerService: AudioInterruptionDelegate {
    var currentSongID: UUID? { currentlyPlayingID }
    func pauseForInterruption() { pause() }
    @discardableResult
    func resumeAfterInterruption() -> Bool { resume() }
}
