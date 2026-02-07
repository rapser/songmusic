//
//  EqualizerUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
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

enum EqualizerPreset: String, CaseIterable, Sendable {
    case flat = "Plano"
    case acoustic = "Acústica"
    case bassBooster = "Intensificador de bajos"
    case bassReducer = "Reductor de bajos"
    case classical = "Clásica"
    case dance = "Dance"
    case deep = "Profunda"
    case electronic = "Electrónica"
    case flat2 = "Simple"
    case hipHop = "Hip-hop"
    case jazz = "Jazz"
    case latin = "Latina"
    case loudness = "Ruidosa"
    case lounge = "Lounge"
    case piano = "Piano"
    case pop = "Pop"
    case rnb = "R&B"
    case rock = "Rock"
    case smallSpeakers = "Altavoces pequeños"
    case spokenWord = "Palabra hablada"
    case trebleBooster = "Intensificador de agudos"
    case trebleReducer = "Reductor de agudos"
    case vocalBooster = "Intensificador de voces"

    var bands: [Float] {
        // Basado en Spotify - 6 bandas
        // Frecuencias: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 15kHz
        switch self {
        case .flat, .flat2:
            return [0, 0, 0, 0, 0, 0]

        case .acoustic:
            return [6, 4, 2, 3, 4, 4]

        case .bassBooster:
            return [9, 7, 5, 0, 0, 0]

        case .bassReducer:
            return [-9, -7, -5, 0, 0, 0]

        case .classical:
            return [5, 4, 2, -1, 3, 5]

        case .dance:
            return [8, 6, 0, 0, 5, 6]

        case .deep:
            return [9, 7, 2, 0, -2, -3]

        case .electronic:
            return [6, 5, 0, -2, 4, 6]

        case .hipHop:
            return [9, 7, 3, 0, 2, 3]

        case .jazz:
            return [4, 3, 2, 2, 3, 3]

        case .latin:
            return [6, 5, 0, -1, 4, 5]

        case .loudness:
            return [7, 5, -2, -3, 3, 6]

        case .lounge:
            return [-2, -1, 2, 3, 1, 2]

        case .piano:
            return [3, 2, 2, 3, 4, 3]

        case .pop:
            return [-1, 0, 3, 5, 3, 0]

        case .rnb:
            return [7, 6, 2, -1, 4, 4]

        case .rock:
            return [7, 5, 1, -2, 4, 5]

        case .smallSpeakers:
            return [7, 6, 3, 1, -2, -4]

        case .spokenWord:
            return [-5, -3, 3, 6, 5, -2]

        case .trebleBooster:
            return [0, 0, 0, 2, 6, 9]

        case .trebleReducer:
            return [0, 0, 0, -2, -6, -9]

        case .vocalBooster:
            return [-3, -2, 4, 6, 4, 0]
        }
    }
}

// MARK: - Sendable Conformance

extension EqualizerUseCases: Sendable {}
