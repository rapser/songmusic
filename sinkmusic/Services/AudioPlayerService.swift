
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
            print("Error al configurar AVAudioSession: \(error.localizedDescription)")
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

        // Conectar: playerNode -> EQ -> mainMixerNode -> output
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: eq, format: format)
        audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: format)

        // Preparar el engine
        audioEngine.prepare()

        print("🎚️ Audio Engine configurado con ecualizador de 10 bandas")
    }

    func play(songID: UUID, url: URL) {
        print("🔍 Intentando reproducir archivo desde la ruta: \(url.path)")

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
                // Detener reproducción anterior
                playerNode.stop()

                // Cargar el archivo de audio
                audioFile = try AVAudioFile(forReading: url)

                guard let audioFile = audioFile else {
                    print("❌ No se pudo cargar el archivo de audio")
                    return
                }

                // Programar el buffer para reproducción
                playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, let currentID = self.currentlyPlayingID else { return }
                        print("🎵 Canción terminada: \(currentID)")
                        self.onSongFinished.send(currentID)
                    }
                }

                // Iniciar el engine si no está corriendo
                if !audioEngine.isRunning {
                    try audioEngine.start()
                }

                // Reproducir
                playerNode.play()

                self.currentlyPlayingID = songID
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: self.currentlyPlayingID))

                print("✅ Reproduciendo con Audio Engine y ecualizador")
            } catch {
                print("❌ Error al iniciar Audio Engine: \(error.localizedDescription)")
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
                  let audioFile = self.audioFile else { return }

            let currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            self.onPlaybackTimeChanged.send((time: currentTime, duration: duration))
        }
    }

    // MARK: - Equalizer
    func applyEqualizerSettings(_ bands: [EqualizerBand]) {
        print("🎚️ Aplicando configuración del ecualizador:")

        for (index, band) in bands.enumerated() where index < eq.bands.count {
            eq.bands[index].gain = Float(band.gain)
            print("  Banda \(index) (\(band.label)): \(band.gain) dB")
        }

        print("✅ Ecualizador actualizado en tiempo real")
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let finishedSongID = currentlyPlayingID else { return }
        currentlyPlayingID = nil
        onPlaybackStateChanged.send((isPlaying: false, songID: finishedSongID))
        onSongFinished.send(finishedSongID)
    }
}
