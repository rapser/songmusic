//
//  StereoProcessingEngine.swift
//  sinkmusic
//
//  Stereo widening avanzado usando procesamiento Mid-Side
//  Este enfoque procesa los canales L/R en componentes Mid (mono) y Side (estéreo)
//  para ampliar el campo estéreo sin artefactos de fase
//

import Foundation
import AVFoundation
import Accelerate

/// Motor de procesamiento estéreo con técnica Mid-Side
/// - Preserva la compatibilidad mono (no se pierde información al colapsar)
/// - Amplía el campo estéreo de forma musical
/// - Usa procesamiento vectorizado (vDSP) para eficiencia
final class StereoProcessingEngine {
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let bassEQ: AVAudioUnitEQ
    private let trebleEQ: AVAudioUnitEQ
    private let mainEQ: AVAudioUnitEQ
    private let compressor: AVAudioUnitEffect
    private let limiter: AVAudioUnitEffect

    // Stereo widening
    private var widthAmount: Float = 0.7 // 0.0 = mono, 1.0 = muy ancho

    private var isFirstConnection = true
    private var isStereoProcessingEnabled = true

    var isRunning: Bool {
        audioEngine.isRunning
    }

    // MARK: - Initialization

    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()

        self.bassEQ = AVAudioUnitEQ(numberOfBands: 3)
        self.trebleEQ = AVAudioUnitEQ(numberOfBands: 3)
        self.mainEQ = AVAudioUnitEQ(numberOfBands: 10)

        self.compressor = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )

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
        configureProcessing()
    }

    // MARK: - Setup

    private func setupNodes() {
        audioEngine.attach(playerNode)
        audioEngine.attach(bassEQ)
        audioEngine.attach(trebleEQ)
        audioEngine.attach(mainEQ)
        audioEngine.attach(compressor)
        audioEngine.attach(limiter)
    }

    private func configureProcessing() {
        // Bass boost (60-120 Hz)
        bassEQ.bands[0].filterType = .lowShelf
        bassEQ.bands[0].frequency = 60
        bassEQ.bands[0].gain = 3.5
        bassEQ.bands[0].bypass = false

        bassEQ.bands[1].filterType = .parametric
        bassEQ.bands[1].frequency = 120
        bassEQ.bands[1].bandwidth = 0.8
        bassEQ.bands[1].gain = 4.0
        bassEQ.bands[1].bypass = false

        bassEQ.bands[2].filterType = .parametric
        bassEQ.bands[2].frequency = 250
        bassEQ.bands[2].bandwidth = 1.2
        bassEQ.bands[2].gain = -1.0 // Reduce mud
        bassEQ.bands[2].bypass = false

        // Treble boost (4k-12k Hz)
        trebleEQ.bands[0].filterType = .parametric
        trebleEQ.bands[0].frequency = 4000
        trebleEQ.bands[0].bandwidth = 1.0
        trebleEQ.bands[0].gain = 2.5
        trebleEQ.bands[0].bypass = false

        trebleEQ.bands[1].filterType = .parametric
        trebleEQ.bands[1].frequency = 8000
        trebleEQ.bands[1].bandwidth = 1.2
        trebleEQ.bands[1].gain = 3.5
        trebleEQ.bands[1].bypass = false

        trebleEQ.bands[2].filterType = .highShelf
        trebleEQ.bands[2].frequency = 12000
        trebleEQ.bands[2].gain = 3.0
        trebleEQ.bands[2].bypass = false

        // Main EQ (10 bandas)
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (index, frequency) in frequencies.enumerated() where index < mainEQ.bands.count {
            mainEQ.bands[index].filterType = .parametric
            mainEQ.bands[index].frequency = frequency
            mainEQ.bands[index].bandwidth = 1.0
            mainEQ.bands[index].gain = 0.0
            mainEQ.bands[index].bypass = false
        }

        // Compressor
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 0)?.value = -20.0 // Threshold
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 1)?.value = 5.0   // Headroom
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 2)?.value = 0.005 // Attack
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 3)?.value = 0.050 // Release
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 4)?.value = 6.0   // Master Gain
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 5)?.value = 50.0  // Amount

        // Limiter
        limiter.auAudioUnit.parameterTree?.parameter(withAddress: 0)?.value = 4.0    // Pre-gain
        limiter.auAudioUnit.parameterTree?.parameter(withAddress: 1)?.value = 0.01   // Release
        limiter.auAudioUnit.parameterTree?.parameter(withAddress: 2)?.value = 0.001  // Attack
    }

    // MARK: - Node Connection

    func getPlayerNode() -> AVAudioPlayerNode {
        playerNode
    }

    func connectNodes(with format: AVAudioFormat) throws {
        guard format.channelCount >= 2 else {
            throw NSError(
                domain: "StereoProcessingEngine",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Requiere formato estéreo"]
            )
        }

        if !isFirstConnection {
            playerNode.reset()
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            audioEngine.disconnectNodeInput(playerNode)
            audioEngine.disconnectNodeInput(bassEQ)
            audioEngine.disconnectNodeInput(trebleEQ)
            audioEngine.disconnectNodeInput(mainEQ)
            audioEngine.disconnectNodeInput(compressor)
            audioEngine.disconnectNodeInput(limiter)
        } else {
            isFirstConnection = false
        }

        // Conectar cadena completa
        audioEngine.connect(playerNode, to: bassEQ, format: format)
        audioEngine.connect(bassEQ, to: trebleEQ, format: format)
        audioEngine.connect(trebleEQ, to: mainEQ, format: format)

        // Instalar tap para stereo widening
        if isStereoProcessingEnabled {
            installStereoWideningTap(on: mainEQ, format: format)
        }

        audioEngine.connect(mainEQ, to: compressor, format: format)
        audioEngine.connect(compressor, to: limiter, format: format)
        audioEngine.connect(limiter, to: audioEngine.mainMixerNode, format: format)

        audioEngine.prepare()
    }

    // MARK: - Stereo Widening (Mid-Side Processing)

    /// Instala un tap en el nodo para procesar stereo widening
    private func installStereoWideningTap(on node: AVAudioNode, format: AVAudioFormat) {
        // Remover tap anterior si existe
        node.removeTap(onBus: 0)

        // Buffer size (1024 samples típico)
        let bufferSize: AVAudioFrameCount = 1024

        node.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processStereoWidening(buffer: buffer)
        }
    }

    /// Procesa el buffer con técnica Mid-Side
    /// Mid = (L + R) / 2  -> Información mono (centro)
    /// Side = (L - R) / 2 -> Información estéreo (laterales)
    /// L' = Mid + (Side * width)
    /// R' = Mid - (Side * width)
    private func processStereoWidening(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData,
              buffer.format.channelCount == 2 else {
            return
        }

        let frameCount = Int(buffer.frameLength)
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        // Vectores temporales para Mid y Side
        var mid = [Float](repeating: 0, count: frameCount)
        var side = [Float](repeating: 0, count: frameCount)
        var tempLeft = [Float](repeating: 0, count: frameCount)
        var tempRight = [Float](repeating: 0, count: frameCount)

        // Copiar canales a arrays temporales usando withUnsafeBufferPointer
        tempLeft.withUnsafeMutableBufferPointer { destLeft in
            UnsafeBufferPointer(start: leftChannel, count: frameCount).withMemoryRebound(to: Float.self) { src in
                _ = destLeft.update(from: src)
            }
        }
        tempRight.withUnsafeMutableBufferPointer { destRight in
            UnsafeBufferPointer(start: rightChannel, count: frameCount).withMemoryRebound(to: Float.self) { src in
                _ = destRight.update(from: src)
            }
        }

        // Calcular Mid = (L + R) / 2
        vDSP_vadd(tempLeft, 1, tempRight, 1, &mid, 1, vDSP_Length(frameCount))
        var halfScale: Float = 0.5
        vDSP_vsmul(mid, 1, &halfScale, &mid, 1, vDSP_Length(frameCount))

        // Calcular Side = (L - R) / 2
        vDSP_vsub(tempRight, 1, tempLeft, 1, &side, 1, vDSP_Length(frameCount))
        vDSP_vsmul(side, 1, &halfScale, &side, 1, vDSP_Length(frameCount))

        // Aplicar width al componente Side
        var scaledSide = [Float](repeating: 0, count: frameCount)
        var widthScale = widthAmount
        vDSP_vsmul(side, 1, &widthScale, &scaledSide, 1, vDSP_Length(frameCount))

        // Reconstruir L' = Mid + Side * width
        vDSP_vadd(mid, 1, scaledSide, 1, &tempLeft, 1, vDSP_Length(frameCount))

        // Reconstruir R' = Mid - Side * width
        vDSP_vsub(scaledSide, 1, mid, 1, &tempRight, 1, vDSP_Length(frameCount))

        // Copiar resultado de vuelta a los canales usando withUnsafeMutableBufferPointer
        tempLeft.withUnsafeBufferPointer { srcLeft in
            UnsafeMutableBufferPointer(start: leftChannel, count: frameCount).withMemoryRebound(to: Float.self) { dest in
                _ = dest.update(from: srcLeft)
            }
        }
        tempRight.withUnsafeBufferPointer { srcRight in
            UnsafeMutableBufferPointer(start: rightChannel, count: frameCount).withMemoryRebound(to: Float.self) { dest in
                _ = dest.update(from: srcRight)
            }
        }
    }

    // MARK: - Control

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

    /// Ajusta la amplitud del estéreo (0.0 = mono, 1.0 = muy ancho)
    /// Valores seguros: 0.5-0.8 (sin artefactos)
    func setStereoWidth(_ width: Float) {
        self.widthAmount = max(0.0, min(1.5, width)) // Limitar 0-1.5
    }

    /// Activa/desactiva el procesamiento estéreo
    func setStereoProcessingEnabled(_ enabled: Bool) {
        self.isStereoProcessingEnabled = enabled
    }

    func updateMainEqualizer(bands: [Float]) {
        guard bands.count <= mainEQ.bands.count else { return }
        for (index, gain) in bands.enumerated() {
            mainEQ.bands[index].gain = gain
        }
    }

    func setBassBoostEnabled(_ enabled: Bool) {
        for band in bassEQ.bands {
            band.bypass = !enabled
        }
    }

    func setTrebleBoostEnabled(_ enabled: Bool) {
        for band in trebleEQ.bands {
            band.bypass = !enabled
        }
    }

    func setCompressionIntensity(_ intensity: Float) {
        let amount = intensity * 100.0
        compressor.auAudioUnit.parameterTree?.parameter(withAddress: 5)?.value = amount
    }

    deinit {
        // Limpiar taps
        mainEQ.removeTap(onBus: 0)
    }
}
