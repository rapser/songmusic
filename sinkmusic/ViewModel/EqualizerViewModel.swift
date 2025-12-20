//
//  EqualizerViewModel.swift
//  sinkmusic
//
//  Created by Claude Code on 19/12/25.
//

import Foundation

/// ViewModel responsable ÚNICAMENTE de la gestión del ecualizador
/// Cumple con Single Responsibility Principle
@MainActor
class EqualizerViewModel: ObservableObject {
    @Published var equalizerBands: [EqualizerBand] = EqualizerBand.defaultBands
    @Published var selectedPreset: EqualizerPreset = .flat

    private var audioPlayerService: AudioPlayerProtocol

    init(audioPlayerService: AudioPlayerProtocol = AudioPlayerService()) {
        self.audioPlayerService = audioPlayerService
    }

    /// Actualiza la ganancia de una banda específica
    /// - Parameters:
    ///   - index: Índice de la banda (0-5)
    ///   - gain: Ganancia en dB (-12 a +12)
    func updateBandGain(index: Int, gain: Double) {
        guard index < equalizerBands.count else { return }

        equalizerBands[index].gain = gain
        selectedPreset = .flat // Reset preset when manually adjusting

        // Convertir EqualizerBand a Float para el protocolo
        let gains = equalizerBands.map { Float($0.gain) }
        audioPlayerService.updateEqualizer(bands: gains)
    }

    /// Aplica un preset predefinido de ecualizador
    /// - Parameter preset: Preset a aplicar (rock, jazz, classical, etc.)
    func applyPreset(_ preset: EqualizerPreset) {
        selectedPreset = preset
        let gains = preset.gains

        for (index, gain) in gains.enumerated() where index < equalizerBands.count {
            equalizerBands[index].gain = gain
        }

        // Convertir EqualizerBand a Float para el protocolo
        let floatGains = equalizerBands.map { Float($0.gain) }
        audioPlayerService.updateEqualizer(bands: floatGains)
    }

    /// Resetea el ecualizador a valores planos (0 dB)
    func resetEqualizer() {
        equalizerBands = EqualizerBand.defaultBands
        selectedPreset = .flat

        // Convertir EqualizerBand a Float para el protocolo
        let gains = equalizerBands.map { Float($0.gain) }
        audioPlayerService.updateEqualizer(bands: gains)
    }
}
