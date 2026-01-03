//
//  EqualizerViewModel.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  SOLID: Single Responsibility - Maneja UI del ecualizador
//

import Foundation
import SwiftUI

/// ViewModel responsable de la UI del ecualizador
/// Delega lógica de negocio a EqualizerUseCases
@MainActor
@Observable
final class EqualizerViewModel {

    // MARK: - Published State

    var band60Hz: Float = 0.0
    var band150Hz: Float = 0.0
    var band400Hz: Float = 0.0
    var band1kHz: Float = 0.0
    var band2_4kHz: Float = 0.0
    var band15kHz: Float = 0.0

    var selectedPreset: EqualizerPreset = .flat
    var isCustom: Bool = true

    // MARK: - Dependencies

    private let equalizerUseCases: EqualizerUseCases

    // MARK: - Initialization

    init(equalizerUseCases: EqualizerUseCases) {
        self.equalizerUseCases = equalizerUseCases
    }

    // MARK: - Band Control

    /// Actualiza las bandas del ecualizador
    func updateBands() async {
        let bands = [
            band60Hz,
            band150Hz,
            band400Hz,
            band1kHz,
            band2_4kHz,
            band15kHz
        ]

        await equalizerUseCases.updateBands(bands)
        isCustom = true
    }

    /// Actualiza una banda específica
    func updateBand(at index: Int, value: Float) async {
        switch index {
        case 0: band60Hz = value
        case 1: band150Hz = value
        case 2: band400Hz = value
        case 3: band1kHz = value
        case 4: band2_4kHz = value
        case 5: band15kHz = value
        default: break
        }

        await updateBands()
    }

    // MARK: - Presets

    /// Aplica un preset predefinido
    func applyPreset(_ preset: EqualizerPreset) async {
        selectedPreset = preset
        isCustom = false

        let bands = preset.bands

        band60Hz = bands[0]
        band150Hz = bands[1]
        band400Hz = bands[2]
        band1kHz = bands[3]
        band2_4kHz = bands[4]
        band15kHz = bands[5]

        await equalizerUseCases.applyPreset(preset)
    }

    /// Resetea el ecualizador
    func reset() async {
        band60Hz = 0.0
        band150Hz = 0.0
        band400Hz = 0.0
        band1kHz = 0.0
        band2_4kHz = 0.0
        band15kHz = 0.0

        selectedPreset = .flat
        isCustom = false

        await equalizerUseCases.reset()
    }

    // MARK: - Helpers

    /// Obtiene el array de bandas actual
    var currentBands: [Float] {
        [band60Hz, band150Hz, band400Hz, band1kHz, band2_4kHz, band15kHz]
    }

    /// Obtiene todos los presets disponibles
    var availablePresets: [EqualizerPreset] {
        [.flat, .bassBoost, .vocal, .treble, .rock, .pop, .classical, .electronic]
    }

    /// Nombres de las frecuencias
    var bandNames: [String] {
        ["60 Hz", "150 Hz", "400 Hz", "1 kHz", "2.4 kHz", "15 kHz"]
    }
}
