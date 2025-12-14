//
//  AdvancedEqualizerView.swift
//  sinkmusic
//
//  Vista de ecualizador avanzado con controles de stereo widening
//

import SwiftUI

struct AdvancedEqualizerView: View {
    @EnvironmentObject var container: DependencyContainer

    // EQ bands (10 bandas)
    @State private var bands: [Float] = Array(repeating: 0.0, count: 10)

    // Procesamiento adicional
    @State private var stereoWidth: Float = 0.7
    @State private var bassBoostEnabled: Bool = true
    @State private var trebleBoostEnabled: Bool = true
    @State private var compressionIntensity: Float = 0.5

    // Presets
    @State private var selectedPreset: PresetType = .spotify
    @State private var showPresetPicker: Bool = false

    // Frecuencias de las 10 bandas
    private let frequencies = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    private var audioPlayer: SpotifyStyleAudioPlayerService? {
        container.audioPlayerService() as? SpotifyStyleAudioPlayerService
    }

    enum PresetType: String, CaseIterable {
        case flat = "Flat"
        case spotify = "Spotify"
        case bassBoost = "Bass Boost"
        case vocal = "Vocal"
        case treble = "Treble"
        case custom = "Custom"

        var bandValues: [Float] {
            switch self {
            case .flat:
                return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            case .spotify:
                return [3, 3.5, 2, -1, 0, 0, 1, 2.5, 3.5, 3]
            case .bassBoost:
                return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
            case .vocal:
                return [0, 0, -1, -1, 2, 3, 2, 0, 0, 0]
            case .treble:
                return [0, 0, 0, 0, 0, 1, 2, 3, 4, 5]
            case .custom:
                return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Preset Selector
                presetSection

                // MARK: - Visualización EQ
                equalizerVisualization

                // MARK: - Sliders EQ
                equalizerSliders

                // MARK: - Stereo Widening
                stereoWideningSection

                // MARK: - Processing Controls
                processingControlsSection

                // MARK: - Info
                infoSection
            }
            .padding()
        }
        .navigationTitle("Ecualizador Avanzado")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    resetToDefault()
                }
            }
        }
        .onAppear {
            applyPreset(.spotify)
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        VStack(spacing: 12) {
            Text("Preset")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PresetType.allCases, id: \.self) { preset in
                        PresetButton(
                            title: preset.rawValue,
                            isSelected: selectedPreset == preset
                        ) {
                            selectedPreset = preset
                            applyPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - EQ Visualization

    private var equalizerVisualization: some View {
        VStack(spacing: 8) {
            Text("Respuesta de Frecuencia")
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    // Grid background
                    Path { path in
                        for i in 0...4 {
                            let y = geometry.size.height * CGFloat(i) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                    // Center line (0 dB)
                    Path { path in
                        let y = geometry.size.height / 2
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.blue.opacity(0.5), lineWidth: 2)

                    // EQ curve
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let bandWidth = width / CGFloat(bands.count - 1)

                        for (index, gain) in bands.enumerated() {
                            let x = bandWidth * CGFloat(index)
                            // Map gain (-12 to +12 dB) to y position
                            let normalizedGain = CGFloat((gain + 12) / 24) // 0-1
                            let y = height * (1 - normalizedGain)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple, .pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )

                    // Dots on curve
                    ForEach(0..<bands.count, id: \.self) { index in
                        let bandWidth = geometry.size.width / CGFloat(bands.count - 1)
                        let x = bandWidth * CGFloat(index)
                        let normalizedGain = CGFloat((bands[index] + 12) / 24)
                        let y = geometry.size.height * (1 - normalizedGain)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                            .shadow(radius: 2)
                    }
                }
            }
            .frame(height: 150)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Frequency labels
            HStack {
                ForEach(0..<frequencies.count, id: \.self) { index in
                    Text(frequencies[index])
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - EQ Sliders

    private var equalizerSliders: some View {
        VStack(spacing: 16) {
            Text("Control de Bandas")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<bands.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        // Gain value
                        Text(String(format: "%.1f", bands[index]))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Vertical slider
                        GeometryReader { geometry in
                            VStack {
                                Spacer()

                                ZStack(alignment: .bottom) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))

                                    // Fill
                                    let normalizedValue = CGFloat((bands[index] + 12) / 24) // 0-1
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.blue, .purple]),
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(height: geometry.size.height * normalizedValue)
                                }
                                .frame(width: 20)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            updateBand(index: index, dragLocation: value.location.y, height: geometry.size.height)
                                        }
                                )
                            }
                        }

                        // Frequency label
                        Text(frequencies[index])
                            .font(.caption2)
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Stereo Widening

    private var stereoWideningSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.blue)
                Text("Stereo Widening")
                    .font(.headline)
                Spacer()
                Text("\(Int(stereoWidth * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Mono")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $stereoWidth, in: 0...1.5, step: 0.1)
                    .onChange(of: stereoWidth) { _, newValue in
                        audioPlayer?.setStereoWidth(newValue)
                    }

                Text("Wide")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stereo width visualization
            HStack(spacing: 4) {
                ForEach(0..<15, id: \.self) { index in
                    let isActive = Float(index) / 15.0 <= stereoWidth / 1.5
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Processing Controls

    private var processingControlsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                Text("Procesamiento")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                Toggle(isOn: $bassBoostEnabled) {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                        Text("Boost de Graves")
                    }
                }
                .onChange(of: bassBoostEnabled) { _, newValue in
                    audioPlayer?.setBassBoost(newValue)
                }

                Toggle(isOn: $trebleBoostEnabled) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("Boost de Agudos")
                    }
                }
                .onChange(of: trebleBoostEnabled) { _, newValue in
                    audioPlayer?.setTrebleBoost(newValue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gauge")
                        Text("Compresión")
                        Spacer()
                        Text("\(Int(compressionIntensity * 100))%")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $compressionIntensity, in: 0...1, step: 0.1)
                        .onChange(of: compressionIntensity) { _, newValue in
                            audioPlayer?.setCompression(newValue)
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.green)
                Text("Estado del Procesamiento")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                InfoRow(icon: "checkmark.circle.fill", text: "Stereo Widening: Activo", color: .green)
                InfoRow(icon: "checkmark.circle.fill", text: "EQ de 10 Bandas: Activo", color: .green)
                InfoRow(icon: "checkmark.circle.fill", text: "Compresión Dinámica: Activa", color: .green)
                InfoRow(icon: "checkmark.circle.fill", text: "Limitador de Picos: Activo", color: .green)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helper Functions

    private func updateBand(index: Int, dragLocation: CGFloat, height: CGFloat) {
        // Invertir el drag (arriba = positivo, abajo = negativo)
        let normalizedValue = 1 - (dragLocation / height)
        let clampedValue = max(0, min(1, normalizedValue))

        // Map 0-1 to -12 to +12 dB
        let gain = (clampedValue * 24) - 12

        bands[index] = Float(gain)
        selectedPreset = .custom
        audioPlayer?.updateEqualizer(bands: bands)
    }

    private func applyPreset(_ preset: PresetType) {
        bands = preset.bandValues
        audioPlayer?.updateEqualizer(bands: bands)

        // Aplicar configuración adicional según preset
        switch preset {
        case .spotify:
            stereoWidth = 0.7
            bassBoostEnabled = true
            trebleBoostEnabled = true
            compressionIntensity = 0.5
            audioPlayer?.applyQualityPreset(.spotify)

        case .bassBoost:
            stereoWidth = 0.6
            bassBoostEnabled = true
            trebleBoostEnabled = false
            compressionIntensity = 0.6

        case .vocal:
            stereoWidth = 0.5
            bassBoostEnabled = false
            trebleBoostEnabled = false
            compressionIntensity = 0.3

        case .treble:
            stereoWidth = 0.8
            bassBoostEnabled = false
            trebleBoostEnabled = true
            compressionIntensity = 0.4

        default:
            break
        }
    }

    private func resetToDefault() {
        selectedPreset = .spotify
        applyPreset(.spotify)
    }
}

// MARK: - Supporting Views

struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
        }
    }
}

// MARK: - Preview

struct AdvancedEqualizerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdvancedEqualizerView()
                .environmentObject(DependencyContainer.shared)
        }
    }
}
