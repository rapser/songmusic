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
    case acoustic = "Acústico"
    case bassBooster = "Bass Booster"
    case bassReducer = "Bass Reducer"
    case classical = "Clásico"
    case dance = "Dance"
    case deep = "Deep"
    case electronic = "Electrónico"
    case hipHop = "Hip Hop"
    case jazz = "Jazz"
    case latin = "Latino"
    case loudness = "Loudness"
    case lounge = "Lounge"
    case piano = "Piano"
    case pop = "Pop"
    case rnb = "R&B"
    case rock = "Rock"
    case smallSpeakers = "Small Speakers"
    case spokenWord = "Spoken Word"
    case trebleBooster = "Treble Booster"
    case trebleReducer = "Treble Reducer"
    case vocalBooster = "Vocal Booster"

    var gains: [Double] {
        // Basado en configuraciones reales de ecualizadores profesionales
        // Frecuencias: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 3.5kHz, 6kHz, 10kHz, 15kHz, 20kHz
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

        case .acoustic:
            // Realza medios y agudos para instrumentos acústicos
            return [6, 4, 2, 2, 3, 3, 4, 4, 3, 2]

        case .bassBooster:
            // Aumenta bajos de forma gradual
            return [9, 7, 5, 3, 0, 0, 0, 0, 0, 0]

        case .bassReducer:
            // Reduce bajos (útil para auriculares con mucho bajo)
            return [-9, -7, -5, -3, 0, 0, 0, 0, 0, 0]

        case .classical:
            // Curva en V: bajos y agudos realzados, medios suaves
            return [5, 4, 3, 2, -1, -2, 0, 3, 4, 5]

        case .dance:
            // Bajos potentes y agudos brillantes
            return [8, 6, 4, 0, 0, 0, 3, 5, 6, 5]

        case .deep:
            // Sub-bajos muy pronunciados
            return [9, 7, 4, 2, 1, 0, -1, -2, -3, -4]

        case .electronic:
            // Bajos y agudos altos, medios recortados
            return [6, 5, 2, 0, -2, -1, 2, 4, 5, 6]

        case .hipHop:
            // Sub-bajos potentes con presencia en medios-bajos
            return [9, 7, 5, 3, -1, 0, 1, 2, 3, 4]

        case .jazz:
            // Medios presentes, bajos controlados
            return [4, 3, 2, 3, 2, 1, 1, 2, 3, 3]

        case .latin:
            // Percusión clara, bajos presentes
            return [6, 5, 3, 0, -1, 0, 2, 4, 5, 4]

        case .loudness:
            // Curva de compensación Fletcher-Munson
            return [7, 5, 0, -2, -3, -2, 0, 3, 5, 6]

        case .lounge:
            // Suave y relajado
            return [-2, -1, 0, 2, 3, 2, 1, 0, 1, 2]

        case .piano:
            // Claridad en medios-altos para piano
            return [3, 2, 1, 2, 3, 4, 5, 4, 3, 2]

        case .pop:
            // Balance equilibrado con presencia vocal
            return [-1, 0, 1, 3, 5, 5, 3, 1, 0, -1]

        case .rnb:
            // Sub-bajos profundos con vocales claras
            return [7, 6, 4, 2, -1, 0, 3, 4, 4, 3]

        case .rock:
            // Bajos potentes, medios cortantes
            return [7, 5, 3, 1, -2, -1, 1, 4, 5, 4]

        case .smallSpeakers:
            // Compensa altavoces pequeños
            return [7, 6, 5, 3, 1, 0, -1, -2, -3, -4]

        case .spokenWord:
            // Claridad vocal (200Hz - 5kHz)
            return [-5, -3, 0, 3, 5, 6, 5, 3, 1, -2]

        case .trebleBooster:
            // Aumenta agudos gradualmente
            return [0, 0, 0, 0, 1, 2, 4, 6, 8, 9]

        case .trebleReducer:
            // Reduce agudos (para grabaciones brillantes)
            return [0, 0, 0, 0, -1, -2, -4, -6, -8, -9]

        case .vocalBooster:
            // Realza frecuencias de voz (1kHz - 4kHz)
            return [-3, -2, 0, 4, 6, 6, 4, 2, 0, -2]
        }
    }
}

struct EqualizerBand {
    let frequency: String
    let label: String
    var gain: Double // -12 to +12 dB

    static let defaultBands: [EqualizerBand] = [
        EqualizerBand(frequency: "60", label: "60", gain: 0),
        EqualizerBand(frequency: "150", label: "150", gain: 0),
        EqualizerBand(frequency: "400", label: "400", gain: 0),
        EqualizerBand(frequency: "1k", label: "1k", gain: 0),
        EqualizerBand(frequency: "2.4k", label: "2.4k", gain: 0),
        EqualizerBand(frequency: "3.5k", label: "3.5k", gain: 0),
        EqualizerBand(frequency: "6k", label: "6k", gain: 0),
        EqualizerBand(frequency: "10k", label: "10k", gain: 0),
        EqualizerBand(frequency: "15k", label: "15k", gain: 0),
        EqualizerBand(frequency: "20k", label: "20k", gain: 0),
    ]
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(songID: PreviewSongs.single().id)
    ) {
        EqualizerView()
    }
}
