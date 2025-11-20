
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

        // NO conectar ni preparar aquí - lo haremos dinámicamente en play() con el formato correcto

        print("🎚️ Audio Engine configurado con ecualizador de 10 bandas")
    }

    func play(songID: UUID, url: URL) {
        print("▶️ AudioPlayerService.play() - Iniciando reproducción")
        print("   Song ID: \(songID.uuidString.prefix(8))...")
        print("   Archivo existe: \(FileManager.default.fileExists(atPath: url.path))")

        if currentlyPlayingID == songID {
            // Si es la misma canción, simplemente reanuda
            print("🔄 Misma canción - Reanudando")
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
            print("🆕 Nueva canción - Cargando archivo")
            do {
                // Cargar el archivo de audio PRIMERO
                print("📂 Intentando cargar AVAudioFile desde: \(url.path)")
                audioFile = try AVAudioFile(forReading: url)

                guard let audioFile = audioFile else {
                    print("❌ No se pudo cargar el archivo de audio (audioFile es nil)")
                    return
                }

                print("✅ AVAudioFile cargado exitosamente")
                print("   - Sample Rate: \(audioFile.processingFormat.sampleRate)")
                print("   - Channels: \(audioFile.processingFormat.channelCount)")
                print("   - Length: \(audioFile.length) frames")
                print("   - Duration: \(Double(audioFile.length) / audioFile.processingFormat.sampleRate) segundos")

                // Reconectar los nodos con el formato del archivo actual
                let fileFormat = audioFile.processingFormat
                print("🔌 Configurando nodos con formato: \(fileFormat.sampleRate) Hz, \(fileFormat.channelCount) canales")

                // Desconectar solo si NO es la primera vez (evita crash)
                if !isFirstConnection {
                    // IMPORTANTE: reset() cancela todos los buffers pendientes y completion handlers
                    playerNode.reset()
                    print("⏹️ Nodo reseteado (cancela completion handlers pendientes)")

                    // Detener el engine antes de desconectar para evitar crash
                    if audioEngine.isRunning {
                        audioEngine.stop()
                        print("⏸️ Audio Engine detenido para reconexión")
                    }

                    audioEngine.disconnectNodeInput(playerNode)
                    audioEngine.disconnectNodeInput(eq)
                    print("✅ Nodos desconectados")
                } else {
                    print("✅ Primera conexión, omitiendo desconexión")
                    isFirstConnection = false
                }

                // Conectar con el formato del archivo
                audioEngine.connect(playerNode, to: eq, format: fileFormat)
                audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: fileFormat)
                print("✅ Nodos conectados correctamente")

                // Preparar el engine después de conectar
                audioEngine.prepare()
                print("✅ Audio Engine preparado")

                // Generar un nuevo ID de schedule para este archivo
                // Esto nos permite ignorar completion handlers de schedules anteriores
                let scheduleID = UUID()
                self.currentScheduleID = scheduleID
                print("📅 Programando archivo para reproducción (Schedule ID: \(scheduleID.uuidString.prefix(8)))")

                let scheduledAt = Date()
                playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                    let completedAt = Date()
                    let elapsed = completedAt.timeIntervalSince(scheduledAt)

                    DispatchQueue.main.async {
                        guard let self = self else {
                            print("⚠️ Completion handler llamado pero self es nil")
                            return
                        }

                        // Verificar si este completion handler es del schedule actual
                        guard self.currentScheduleID == scheduleID else {
                            print("🚫 Completion handler IGNORADO - Schedule ID obsoleto (\(scheduleID.uuidString.prefix(8))) vs actual (\(self.currentScheduleID.uuidString.prefix(8))) - Elapsed: \(elapsed)s")
                            return
                        }

                        guard let currentID = self.currentlyPlayingID else {
                            print("⚠️ Completion handler válido pero currentID es nil")
                            return
                        }

                        print("⏰ Completion handler VÁLIDO ejecutado después de \(elapsed) segundos - Song ID: \(currentID)")
                        print("🎵 Canción terminada: \(currentID)")

                        // Detener el timer de reproducción
                        self.playbackTimer?.invalidate()
                        self.playbackTimer = nil

                        self.onSongFinished.send(currentID)
                    }
                }
                print("✅ Archivo programado en playerNode")

                // Iniciar el engine si no está corriendo
                if !audioEngine.isRunning {
                    print("🎛️ Iniciando Audio Engine")
                    try audioEngine.start()
                    print("✅ Audio Engine iniciado")
                } else {
                    print("✅ Audio Engine ya estaba corriendo")
                }

                // Reproducir
                playerNode.play()

                // Actualizar el ID interno y notificar
                self.currentlyPlayingID = songID
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: songID))

                print("✅ Reproducción iniciada exitosamente")
            } catch {
                print("❌ Error al iniciar Audio Engine: \(error.localizedDescription)")
                print("❌ Error completo: \(error)")
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

            // Debug: verificar si el tiempo es consistente con el ID de canción
            if self.currentlyPlayingID != nil {
                // Solo imprimir cada 5 segundos para no saturar
                let shouldPrint = Int(currentTime) % 5 == 0 && Int(currentTime * 10) % 10 == 0
                if shouldPrint {
                    print("⏱️ Tiempo actual: \(currentTime) / \(duration) - Song ID: \(self.currentlyPlayingID?.uuidString ?? "nil")")
                }
            }

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
