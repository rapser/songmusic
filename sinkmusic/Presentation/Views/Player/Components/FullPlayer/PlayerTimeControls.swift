//
//  PlayerTimeControls.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Controles de tiempo (slider y labels)
struct PlayerTimeControls: View {
    @Binding var sliderValue: Double
    @Binding var isSeekingManually: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let formatTime: (TimeInterval) -> String
    let onSeek: (Double) -> Void

    var body: some View {
        VStack {
            Slider(
                value: $sliderValue,
                in: 0...(duration > 0 ? duration : 1),
                onEditingChanged: { editing in
                    isSeekingManually = editing
                    if !editing {
                        onSeek(sliderValue)
                    }
                }
            )
            .accentColor(.white)

            HStack {
                Text(formatTime(isSeekingManually ? sliderValue : currentTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption)
            .foregroundColor(.textGray)
        }
        .padding(.horizontal, 20)
    }
}
