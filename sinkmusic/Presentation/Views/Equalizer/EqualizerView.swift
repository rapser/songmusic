//
//  EqualizerView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct EqualizerView: View {
    @Environment(EqualizerViewModel.self) private var equalizerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

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

                    Button(action: { equalizerViewModel.resetEqualizer() }) {
                        Text("Restaurar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textGray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 25)

                // Presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                            Button(action: { equalizerViewModel.applyPreset(preset) }) {
                                Text(preset.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(equalizerViewModel.selectedPreset == preset ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(equalizerViewModel.selectedPreset == preset ? Color.appPurple : Color.appGray.opacity(0.3))
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
                        ForEach(Array(equalizerViewModel.equalizerBands.enumerated()), id: \.offset) { index, band in
                            VStack(spacing: 6) {
                                // Valor actual
                                Text(String(format: "%.0f", band.gain))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.textGray)
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
                                                            gradient: Gradient(colors: [Color.appPurple.opacity(0.8), Color.appPurple]),
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
                                                            gradient: Gradient(colors: [Color.appPurple, Color.appPurple.opacity(0.8)]),
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
                                                equalizerViewModel.updateBandGain(index: index, gain: clampedGain)
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

#Preview {
    PreviewWrapper(
        equalizerVM: PreviewViewModels.equalizerVM()
    ) {
        EqualizerView()
    }
}
