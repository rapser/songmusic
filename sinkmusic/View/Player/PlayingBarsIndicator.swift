//
//  PlayingBarsIndicator.swift
//  sinkmusic
//
//  Created by Miguel Tomairo on 19/12/25.
//

import SwiftUI

struct PlayingBarsIndicator: View {
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            BarView(isPlaying: isPlaying, speed: 0.35, minHeight: 3, maxHeight: 14)
            BarView(isPlaying: isPlaying, speed: 0.55, minHeight: 2, maxHeight: 12)
            BarView(isPlaying: isPlaying, speed: 0.45, minHeight: 4, maxHeight: 13)
        }
        .frame(width: 14, height: 14, alignment: .bottom)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Playing:")
            PlayingBarsIndicator(isPlaying: true)
        }

        HStack {
            Text("Paused:")
            PlayingBarsIndicator(isPlaying: false)
        }
    }
    .padding()
    .background(Color.appDark)
}
