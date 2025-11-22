//
//  EqualizerView.swift
//  sinkmusic
//
//  Created by Claude Code
//

import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Ecualizador")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { playerViewModel.resetEqualizer() }) {
                        Text("Restaurar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.spotifyLightGray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 25)

                // Presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                            Button(action: { playerViewModel.applyPreset(preset) }) {
                                Text(preset.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(playerViewModel.selectedPreset == preset ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(playerViewModel.selectedPreset == preset ? Color.spotifyGreen : Color.spotifyGray.opacity(0.3))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)

                // Frequency Bands
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(Array(playerViewModel.equalizerBands.enumerated()), id: \.offset) { index, band in
                            VStack(spacing: 6) {
                                // Valor actual
                                Text(String(format: "%.0f", band.gain))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.spotifyLightGray)
                                    .frame(height: 14)

                                // Slider vertical
                                GeometryReader { geometry in
                                    let normalizedGain = (band.gain + 12) / 24 // 0 a 1
                                    let centerY = geometry.size.height / 2
                                    let knobY = (1 - normalizedGain) * geometry.size.height

                                    ZStack(alignment: .top) {
                                        // Fondo del slider
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                            .frame(width: 5)

                                        // Línea central (0 dB)
                                        Rectangle()
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 16, height: 2)
                                            .position(x: geometry.size.width / 2, y: centerY)

                                        // Parte activa del slider
                                        VStack(spacing: 0) {
                                            if band.gain >= 0 {
                                                // Ganancia positiva: desde knob hasta centro
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [Color.spotifyGreen.opacity(0.8), Color.spotifyGreen]),
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 5)
                                                    .frame(height: centerY - knobY)
                                                    .position(x: geometry.size.width / 2, y: knobY + (centerY - knobY) / 2)
                                            } else {
                                                // Ganancia negativa: desde centro hasta knob
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [Color.spotifyGreen, Color.spotifyGreen.opacity(0.8)]),
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 5)
                                                    .frame(height: knobY - centerY)
                                                    .position(x: geometry.size.width / 2, y: centerY + (knobY - centerY) / 2)
                                            }
                                        }

                                        // Indicador circular (knob)
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.white, Color.white.opacity(0.9)]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 20, height: 20)
                                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                            .position(x: geometry.size.width / 2, y: knobY)
                                    }
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let newY = min(max(value.location.y, 0), geometry.size.height)
                                                let normalizedValue = 1 - (newY / geometry.size.height)
                                                let newGain = (normalizedValue * 24) - 12
                                                let clampedGain = max(-12, min(12, newGain))
                                                playerViewModel.updateBandGain(index: index, gain: clampedGain)
                                            }
                                    )
                                }
                                .frame(height: 200)

                                // Etiqueta de frecuencia
                                Text(band.label)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
        }
    }
}

enum EqualizerPreset: String, CaseIterable {
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

    var gains: [Double] {
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

struct EqualizerBand {
    let frequency: String
    let label: String
    var gain: Double // -12 to +12 dB

    static let defaultBands: [EqualizerBand] = [
        EqualizerBand(frequency: "60", label: "60 Hz", gain: 0),
        EqualizerBand(frequency: "150", label: "150 Hz", gain: 0),
        EqualizerBand(frequency: "400", label: "400 Hz", gain: 0),
        EqualizerBand(frequency: "1k", label: "1 KHz", gain: 0),
        EqualizerBand(frequency: "2.4k", label: "2.4 KHz", gain: 0),
        EqualizerBand(frequency: "15k", label: "15 KHz", gain: 0),
    ]
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(songID: PreviewSongs.single().id)
    ) {
        EqualizerView()
    }
}
