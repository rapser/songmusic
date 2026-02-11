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
            BarView(isPlaying: isPlaying, minHeight: 2, maxHeight: 16, delay: 0)
            BarView(isPlaying: isPlaying, minHeight: 2, maxHeight: 16, delay: 0.05)
            BarView(isPlaying: isPlaying, minHeight: 2, maxHeight: 16, delay: 0.1)
        }
        .frame(width: 14, height: 16, alignment: .bottom)
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
