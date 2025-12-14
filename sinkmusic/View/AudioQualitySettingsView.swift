//
//  AudioQualitySettingsView.swift
//  sinkmusic
//
//  Vista simplificada de configuración de calidad de audio
//  Diseño consistente con el estilo Spotify de la app
//

import SwiftUI

struct AudioQualitySettingsView: View {
    @EnvironmentObject var container: DependencyContainer

    @State private var selectedPreset: QualityPreset = .spotify
    @State private var stereoWidth: Float = 0.7
    @State private var showAdvancedEQ: Bool = false

    private var audioPlayer: SpotifyStyleAudioPlayerService? {
        container.audioPlayerService() as? SpotifyStyleAudioPlayerService
    }

    enum QualityPreset: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case spotify = "Premium"
        case audiophile = "Audiophile"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .standard:
                return "Calidad básica, menor uso de CPU"
            case .spotify:
                return "Calidad óptima, recomendado"
            case .audiophile:
                return "Máxima calidad, mayor uso de CPU"
            }
        }

        var icon: String {
            switch self {
            case .standard:
                return "speaker.wave.1.fill"
            case .spotify:
                return "speaker.wave.2.fill"
            case .audiophile:
                return "speaker.wave.3.fill"
            }
        }

        var color: Color {
            switch self {
            case .standard:
                return .blue
            case .spotify:
                return .appPurple
            case .audiophile:
                return .purple
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title)
                                .foregroundColor(.appPurple)

                            Text("Calidad de Audio")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        Text("Optimiza el sonido de tu música local")
                            .font(.subheadline)
                            .foregroundColor(.textGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Presets de Calidad
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preset de Calidad")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(QualityPreset.allCases) { preset in
                                PresetCard(
                                    preset: preset,
                                    isSelected: selectedPreset == preset
                                ) {
                                    selectPreset(preset)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Stereo Widening
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amplitud Estéreo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "waveform.circle")
                                    .foregroundColor(.appPurple)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stereo Widening")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Text("\(Int(stereoWidth * 100))% - \(widthDescription)")
                                        .font(.caption)
                                        .foregroundColor(.textGray)
                                }
                                Spacer()
                            }

                            HStack(spacing: 12) {
                                Text("Mono")
                                    .font(.caption)
                                    .foregroundColor(.textGray)

                                Slider(value: $stereoWidth, in: 0...1.5, step: 0.1)
                                    .accentColor(.appPurple)
                                    .onChange(of: stereoWidth) { _, newValue in
                                        audioPlayer?.setStereoWidth(newValue)
                                    }

                                Text("Wide")
                                    .font(.caption)
                                    .foregroundColor(.textGray)
                            }

                            // Visual indicator
                            GeometryReader { geometry in
                                HStack(spacing: 2) {
                                    ForEach(0..<20, id: \.self) { index in
                                        let threshold = Float(index) / 20.0 * 1.5
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(stereoWidth >= threshold ? Color.appPurple : Color.gray.opacity(0.3))
                                            .frame(height: 6)
                                    }
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding()
                        .background(Color.appGray)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Características Activas
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Procesamiento Activo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "Stereo Widening Mid-Side",
                                subtitle: "Campo estéreo amplio sin artefactos",
                                color: .green
                            )

                            Divider()
                                .background(Color.textGray.opacity(0.3))

                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "EQ Optimizado",
                                subtitle: "Graves potentes + agudos brillantes",
                                color: .green
                            )

                            Divider()
                                .background(Color.textGray.opacity(0.3))

                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "Compresión Dinámica",
                                subtitle: "Volumen consistente y punch",
                                color: .green
                            )

                            Divider()
                                .background(Color.textGray.opacity(0.3))

                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "Limitador de Picos",
                                subtitle: "Volumen alto sin distorsión",
                                color: .green
                            )
                        }
                        .background(Color.appGray)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Ecualizador Avanzado
                    Button(action: {
                        showAdvancedEQ = true
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.white)
                            Text("Ecualizador Avanzado")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textGray)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.appPurple)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Información")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Text("Esta configuración mejora la calidad de audio de tus archivos locales AAC/M4A con procesamiento profesional. Todo el procesamiento se realiza en tiempo real sin modificar los archivos originales.")
                            .font(.caption)
                            .foregroundColor(.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.appGray.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdvancedEQ) {
            NavigationView {
                AdvancedEqualizerView()
                    .environmentObject(container)
            }
        }
        .onAppear {
            applyStoredPreset()
        }
    }

    private var widthDescription: String {
        switch stereoWidth {
        case 0..<0.3:
            return "Mono"
        case 0.3..<0.6:
            return "Estrecho"
        case 0.6..<0.8:
            return "Natural"
        case 0.8..<1.2:
            return "Amplio"
        default:
            return "Muy amplio"
        }
    }

    private func selectPreset(_ preset: QualityPreset) {
        selectedPreset = preset

        switch preset {
        case .standard:
            audioPlayer?.applyQualityPreset(.standard)
            stereoWidth = 0.5
        case .spotify:
            audioPlayer?.applyQualityPreset(.spotify)
            stereoWidth = 0.7
        case .audiophile:
            audioPlayer?.applyQualityPreset(.audiophile)
            stereoWidth = 0.8
        }

        // Guardar preferencia
        UserDefaults.standard.set(preset.rawValue, forKey: "audioQualityPreset")
    }

    private func applyStoredPreset() {
        if let storedPreset = UserDefaults.standard.string(forKey: "audioQualityPreset"),
           let preset = QualityPreset(rawValue: storedPreset) {
            selectPreset(preset)
        } else {
            selectPreset(.spotify)
        }
    }
}

// MARK: - Supporting Views

struct PresetCard: View {
    let preset: AudioQualitySettingsView.QualityPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? preset.color : .textGray)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(preset.color)
                }
            }
            .padding()
            .background(isSelected ? preset.color.opacity(0.2) : Color.appGray)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? preset.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textGray)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AudioQualitySettingsView()
            .environmentObject(DependencyContainer.shared)
    }
}
