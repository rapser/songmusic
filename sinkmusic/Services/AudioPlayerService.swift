
import Foundation
import AVFoundation
import Combine

class AudioPlayerService: NSObject, AVAudioPlayerDelegate {

    // Publishers para que el ViewModel pueda suscribirse a los cambios
    var onPlaybackStateChanged = PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never>()
    var onPlaybackTimeChanged = PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never>()
    var onSongFinished = PassthroughSubject<UUID, Never>()

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?

    // Audio Engine para ecualizador
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var eq: AVAudioUnitEQ
    private var useAudioEngine = true // Flag para usar engine con ecualizador
    private var isFirstConnection = true // Flag para saber si es la primera vez que conectamos
    private var currentScheduleID = UUID() // ID único para cada scheduleFile, para ignorar completion handlers obsoletos

    override init() {
        // Inicializar Audio Engine y nodos
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()

        // Crear ecualizador de 10 bandas
        self.eq = AVAudioUnitEQ(numberOfBands: 10)

        super.init()
        setupAudioSession()
        setupAudioEngine()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }

    private func setupAudioEngine() {
        // Adjuntar los nodos al engine
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)

        // Configurar las bandas del ecualizador con frecuencias específicas
        let frequencies: [Float] = [60, 150, 400, 1000, 2400, 3500, 6000, 10000, 15000, 20000]
        for (index, frequency) in frequencies.enumerated() where index < eq.bands.count {
            eq.bands[index].filterType = .parametric
            eq.bands[index].frequency = frequency
            eq.bands[index].bandwidth = 1.0
            eq.bands[index].gain = 0.0
            eq.bands[index].bypass = false
        }

        // NO conectar ni preparar aquí - lo haremos dinámicamente en play() con el formato correcto
    }

    func play(songID: UUID, url: URL) {
        if currentlyPlayingID == songID {
            // Si es la misma canción, simplemente reanuda
            if !playerNode.isPlaying {
                playerNode.play()
                if !audioEngine.isRunning {
                    try? audioEngine.start()
                }
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: self.currentlyPlayingID))
            }
        } else {
            // Es una canción nueva
            do {
                // Cargar el archivo de audio PRIMERO
                audioFile = try AVAudioFile(forReading: url)

                guard let audioFile = audioFile else {
                    return
                }

                // Reconectar los nodos con el formato del archivo actual
                let fileFormat = audioFile.processingFormat

                // Desconectar solo si NO es la primera vez (evita crash)
                if !isFirstConnection {
                    // IMPORTANTE: reset() cancela todos los buffers pendientes y completion handlers
                    playerNode.reset()

                    // Detener el engine antes de desconectar para evitar crash
                    if audioEngine.isRunning {
                        audioEngine.stop()
                    }

                    audioEngine.disconnectNodeInput(playerNode)
                    audioEngine.disconnectNodeInput(eq)
                } else {
                    isFirstConnection = false
                }

                // Conectar con el formato del archivo
                audioEngine.connect(playerNode, to: eq, format: fileFormat)
                audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: fileFormat)

                // Preparar el engine después de conectar
                audioEngine.prepare()

                // Generar un nuevo ID de schedule para este archivo
                // Esto nos permite ignorar completion handlers de schedules anteriores
                let scheduleID = UUID()
                self.currentScheduleID = scheduleID

                playerNode.scheduleFile(audioFile, at: nil) { [weak self] in

                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }

                        // Verificar si este completion handler es del schedule actual
                        guard self.currentScheduleID == scheduleID else {
                            return
                        }

                        guard let currentID = self.currentlyPlayingID else {
                            return
                        }

                        // Detener el timer de reproducción
                        self.playbackTimer?.invalidate()
                        self.playbackTimer = nil

                        self.onSongFinished.send(currentID)
                    }
                }

                // Iniciar el engine si no está corriendo
                if !audioEngine.isRunning {
                    try audioEngine.start()
                }

                // Reproducir
                playerNode.play()

                // Actualizar el ID interno y notificar
                self.currentlyPlayingID = songID
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: songID))
            } catch {
                onPlaybackStateChanged.send((isPlaying: false, songID: nil))
            }
        }
    }

    func pause() {
        playerNode.pause()
        playbackTimer?.invalidate()
        onPlaybackStateChanged.send((isPlaying: false, songID: self.currentlyPlayingID))
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        playbackTimer?.invalidate()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        audioFile = nil
        onPlaybackStateChanged.send((isPlaying: false, songID: oldID))
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }

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
                    guard let self = self, let currentID = self.currentlyPlayingID else { return }

                    // Detener el timer de reproducción
                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil

                    self.onSongFinished.send(currentID)
                }
            }

            playerNode.play()
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

            let currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            self.onPlaybackTimeChanged.send((time: currentTime, duration: duration))
        }
    }

    // MARK: - Equalizer
    func applyEqualizerSettings(_ bands: [EqualizerBand]) {
        for (index, band) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].gain = Float(band.gain)
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let finishedSongID = currentlyPlayingID else { return }
        currentlyPlayingID = nil
        onPlaybackStateChanged.send((isPlaying: false, songID: finishedSongID))
        onSongFinished.send(finishedSongID)
    }
}
