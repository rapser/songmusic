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

                    Button(action: { Task { await equalizerViewModel.reset() } }) {
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
                            Button(action: {
                                Task {
                                    await equalizerViewModel.applyPreset(preset)
                                }
                            }) {
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
                EqualizerBandsView()

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
