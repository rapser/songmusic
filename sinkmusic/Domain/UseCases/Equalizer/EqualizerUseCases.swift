//
//  EqualizerUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para el ecualizador de audio
/// Gestiona presets y configuración de bandas
@MainActor
final class EqualizerUseCases {

    // MARK: - Dependencies

    private let audioPlayerRepository: AudioPlayerRepositoryProtocol

    // MARK: - Initialization

    init(audioPlayerRepository: AudioPlayerRepositoryProtocol) {
        self.audioPlayerRepository = audioPlayerRepository
    }

    // MARK: - Equalizer Control

    /// Actualiza las bandas del ecualizador
    func updateBands(_ bands: [Float]) async {
        await audioPlayerRepository.updateEqualizer(bands: bands)
    }

    /// Aplica un preset predefinido
    func applyPreset(_ preset: EqualizerPreset) async {
        await audioPlayerRepository.updateEqualizer(bands: preset.bands)
    }

    /// Resetea el ecualizador a valores planos (0.0)
    func reset() async {
        let flatBands = Array(repeating: Float(0.0), count: 6)
        await audioPlayerRepository.updateEqualizer(bands: flatBands)
    }
}

// MARK: - Equalizer Presets

enum EqualizerPreset {
    case flat
    case bassBoost
    case vocal
    case treble
    case rock
    case pop
    case classical
    case electronic

    var bands: [Float] {
        switch self {
        case .flat:
            return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .bassBoost:
            return [8.0, 6.0, 3.0, 0.0, 0.0, 0.0]
        case .vocal:
            return [-2.0, -1.0, 2.0, 4.0, 3.0, 1.0]
        case .treble:
            return [0.0, 0.0, 0.0, 3.0, 6.0, 8.0]
        case .rock:
            return [6.0, 4.0, 2.0, -1.0, 3.0, 5.0]
        case .pop:
            return [3.0, 2.0, 0.0, 2.0, 4.0, 4.0]
        case .classical:
            return [4.0, 2.0, -2.0, -2.0, 0.0, 3.0]
        case .electronic:
            return [6.0, 4.0, 0.0, 2.0, 4.0, 6.0]
        }
    }

    var name: String {
        switch self {
        case .flat: return "Plano"
        case .bassBoost: return "Potenciar Graves"
        case .vocal: return "Vocal"
        case .treble: return "Agudos"
        case .rock: return "Rock"
        case .pop: return "Pop"
        case .classical: return "Clásica"
        case .electronic: return "Electrónica"
        }
    }
}

// MARK: - Sendable Conformance

extension EqualizerUseCases: Sendable {}
