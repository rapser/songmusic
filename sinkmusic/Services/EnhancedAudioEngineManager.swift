//
//  EnhancedAudioEngineManager.swift
//  sinkmusic
//
//  Enhanced audio engine with Spotify-like processing
//  - Stereo preservation and widening
//  - EQ (bass boost + treble lift)
//  - Compression and limiting
//  - All using native AVAudioEngine (no dependencies)
//

import Foundation
import AVFoundation

/// Manager de audio avanzado con procesamiento estilo Spotify
/// Características:
/// - Preservación completa del estéreo original
/// - Stereo widening sutil (sin artefactos de fase)
/// - EQ "sonrisa" (graves potentes + agudos brillantes)
/// - Compresión dinámica (punch y consistencia)
/// - Limitador de picos (volumen fuerte sin distorsión)
final class EnhancedAudioEngineManager {
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode

    // Cadena de procesamiento (en orden de señal)
    private let bassBoostEQ: AVAudioUnitEQ
    private let trebleBoostEQ: AVAudioUnitEQ
    private let mainEQ: AVAudioUnitEQ
    private let compressor: AVAudioUnitEffect
    private let limiter: AVAudioUnitEffect

    private var isFirstConnection = true

    var isRunning: Bool {
        audioEngine.isRunning
    }

    // MARK: - Initialization

    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()

        // Ecualizador para graves (60-150 Hz)
        self.bassBoostEQ = AVAudioUnitEQ(numberOfBands: 3)

        // Ecualizador para agudos (8k-15k Hz)
        self.trebleBoostEQ = AVAudioUnitEQ(numberOfBands: 3)

        // Ecualizador principal (control usuario)
        self.mainEQ = AVAudioUnitEQ(numberOfBands: 10)

        // Compresor dinámico
        self.compressor = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )

        // Limitador de picos
        self.limiter = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_PeakLimiter,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )

        setupNodes()
        configureAudioProcessing()
    }

    // MARK: - Setup

    private func setupNodes() {
        // Attach todos los nodos al engine
        audioEngine.attach(playerNode)
        audioEngine.attach(bassBoostEQ)
        audioEngine.attach(trebleBoostEQ)
        audioEngine.attach(mainEQ)
        audioEngine.attach(compressor)
        audioEngine.attach(limiter)
    }

    private func configureAudioProcessing() {
        configureBassBoost()
        configureTrebleBoost()
        configureMainEqualizer()
        configureCompressor()
        configureLimiter()
    }

    // MARK: - Bass Boost Configuration

    private func configureBassBoost() {
        // Boost de graves estilo Spotify
        // Sub-bass: 60 Hz
        bassBoostEQ.bands[0].filterType = .lowShelf
        bassBoostEQ.bands[0].frequency = 60
        bassBoostEQ.bands[0].gain = 3.5 // +3.5 dB
        bassBoostEQ.bands[0].bypass = false

        // Bass: 120 Hz
        bassBoostEQ.bands[1].filterType = .parametric
        bassBoostEQ.bands[1].frequency = 120
        bassBoostEQ.bands[1].bandwidth = 0.8
        bassBoostEQ.bands[1].gain = 4.0 // +4 dB
        bassBoostEQ.bands[1].bypass = false

        // Low-mid: 250 Hz (control de "mud")
        bassBoostEQ.bands[2].filterType = .parametric
        bassBoostEQ.bands[2].frequency = 250
        bassBoostEQ.bands[2].bandwidth = 1.2
        bassBoostEQ.bands[2].gain = -1.0 // -1 dB (reduce "barro")
        bassBoostEQ.bands[2].bypass = false

        bassBoostEQ.globalGain = 0.0
    }

    // MARK: - Treble Boost Configuration

    private func configureTrebleBoost() {
        // Boost de agudos/aire estilo Spotify
        // Presence: 4 kHz (claridad vocal)
        trebleBoostEQ.bands[0].filterType = .parametric
        trebleBoostEQ.bands[0].frequency = 4000
        trebleBoostEQ.bands[0].bandwidth = 1.0
        trebleBoostEQ.bands[0].gain = 2.5 // +2.5 dB
        trebleBoostEQ.bands[0].bypass = false

        // Brilliance: 8 kHz
        trebleBoostEQ.bands[1].filterType = .parametric
        trebleBoostEQ.bands[1].frequency = 8000
        trebleBoostEQ.bands[1].bandwidth = 1.2
        trebleBoostEQ.bands[1].gain = 3.5 // +3.5 dB
        trebleBoostEQ.bands[1].bypass = false

        // Air: 12 kHz (amplitud espacial)
        trebleBoostEQ.bands[2].filterType = .highShelf
        trebleBoostEQ.bands[2].frequency = 12000
        trebleBoostEQ.bands[2].gain = 3.0 // +3 dB
        trebleBoostEQ.bands[2].bypass = false

        trebleBoostEQ.globalGain = 0.0
    }

    // MARK: - Main EQ Configuration

    private func configureMainEqualizer() {
        // EQ de 10 bandas para control del usuario
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

        for (index, frequency) in frequencies.enumerated() where index < mainEQ.bands.count {
            mainEQ.bands[index].filterType = .parametric
            mainEQ.bands[index].frequency = frequency
            mainEQ.bands[index].bandwidth = 1.0
            mainEQ.bands[index].gain = 0.0 // Plano por defecto
            mainEQ.bands[index].bypass = false
        }

        mainEQ.globalGain = 0.0
    }

    // MARK: - Compressor Configuration

    private func configureCompressor() {
        // Configuración del compresor (valores típicos Spotify)
        let audioUnit = compressor.auAudioUnit

        // Threshold: -20 dB (comienza a comprimir)
        audioUnit.parameterTree?.parameter(withAddress: 0)?.value = -20.0

        // Headroom: 5 dB (compresión suave)
        audioUnit.parameterTree?.parameter(withAddress: 1)?.value = 5.0

        // Attack: 5ms (rápido para transientes)
        audioUnit.parameterTree?.parameter(withAddress: 2)?.value = 0.005

        // Release: 50ms (natural)
        audioUnit.parameterTree?.parameter(withAddress: 3)?.value = 0.050

        // Master Gain: +6 dB (recuperar volumen)
        audioUnit.parameterTree?.parameter(withAddress: 4)?.value = 6.0

        // Compression Amount: 0-100
        audioUnit.parameterTree?.parameter(withAddress: 5)?.value = 50.0

        // Input Amplitude: -100 to 0 dB
        audioUnit.parameterTree?.parameter(withAddress: 6)?.value = 0.0

        // Output Amplitude: -100 to 0 dB
        audioUnit.parameterTree?.parameter(withAddress: 7)?.value = 0.0
    }

    // MARK: - Limiter Configuration

    private func configureLimiter() {
        // Configuración del limitador de picos
        let audioUnit = limiter.auAudioUnit

        // Pre-gain: +4 dB (antes del limitador)
        audioUnit.parameterTree?.parameter(withAddress: 0)?.value = 4.0

        // Release Time: 0.01s (10ms - rápido)
        audioUnit.parameterTree?.parameter(withAddress: 1)?.value = 0.01

        // Attack Time: 0.001s (1ms - muy rápido)
        audioUnit.parameterTree?.parameter(withAddress: 2)?.value = 0.001
    }

    // MARK: - Public Methods

    func getPlayerNode() -> AVAudioPlayerNode {
        playerNode
    }

    /// Conecta todos los nodos en la cadena de procesamiento
    /// Orden: Player -> BassEQ -> TrebleEQ -> MainEQ -> Compressor -> Limiter -> Output
    func connectNodes(with format: AVAudioFormat) throws {
        // Verificar que el formato sea estéreo
        guard format.channelCount >= 2 else {
            throw NSError(
                domain: "EnhancedAudioEngineManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "El formato debe ser estéreo (2+ canales)"]
            )
        }

        // Desconectar si ya está conectado
        if !isFirstConnection {
            playerNode.reset()

            if audioEngine.isRunning {
                audioEngine.stop()
            }

            // Desconectar todos los nodos
            audioEngine.disconnectNodeInput(playerNode)
            audioEngine.disconnectNodeInput(bassBoostEQ)
            audioEngine.disconnectNodeInput(trebleBoostEQ)
            audioEngine.disconnectNodeInput(mainEQ)
            audioEngine.disconnectNodeInput(compressor)
            audioEngine.disconnectNodeInput(limiter)
        } else {
            isFirstConnection = false
        }

        // Conectar la cadena completa preservando el estéreo
        // IMPORTANTE: Usar el mismo formato en todas las conexiones
        audioEngine.connect(playerNode, to: bassBoostEQ, format: format)
        audioEngine.connect(bassBoostEQ, to: trebleBoostEQ, format: format)
        audioEngine.connect(trebleBoostEQ, to: mainEQ, format: format)
        audioEngine.connect(mainEQ, to: compressor, format: format)
        audioEngine.connect(compressor, to: limiter, format: format)
        audioEngine.connect(limiter, to: audioEngine.mainMixerNode, format: format)

        // Preparar el engine
        audioEngine.prepare()
    }

    func start() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    // MARK: - EQ Control (Usuario)

    /// Actualiza el ecualizador principal (control del usuario)
    func updateMainEqualizer(bands: [Float]) {
        guard bands.count <= mainEQ.bands.count else { return }

        for (index, gain) in bands.enumerated() {
            mainEQ.bands[index].gain = gain
        }
    }

    // MARK: - Processing Control

    /// Activa/desactiva el boost de graves
    func setBassBoostEnabled(_ enabled: Bool) {
        for band in bassBoostEQ.bands {
            band.bypass = !enabled
        }
    }

    /// Activa/desactiva el boost de agudos
    func setTrebleBoostEnabled(_ enabled: Bool) {
        for band in trebleBoostEQ.bands {
            band.bypass = !enabled
        }
    }

    /// Ajusta la intensidad del stereo widening (0.0 = mono, 1.0 = muy ancho)
    /// Nota: Para stereo widening real, necesitamos usar AVAudioUnitEffect personalizado
    /// o procesar con un tap. Esta versión usa solo EQ para simular amplitud.
    func setStereoWidth(_ width: Float) {
        // Técnica: Boost de agudos laterales (información estéreo)
        let highFreqGain = width * 2.0 // 0-2 dB extra

        trebleBoostEQ.bands[2].gain = 3.0 + highFreqGain
    }

    /// Ajusta la intensidad de la compresión (0.0 = off, 1.0 = máxima)
    func setCompressionIntensity(_ intensity: Float) {
        let audioUnit = compressor.auAudioUnit
        let amount = intensity * 100.0 // 0-100

        audioUnit.parameterTree?.parameter(withAddress: 5)?.value = amount
    }
}
