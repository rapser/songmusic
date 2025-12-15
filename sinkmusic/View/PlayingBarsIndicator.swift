//
//  PlayingBarsIndicator.swift
//  sinkmusic
//
//  Created by Claude Code
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

struct BarView: View {
    let isPlaying: Bool
    let speed: Double
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var height: CGFloat

    init(isPlaying: Bool, speed: Double, minHeight: CGFloat, maxHeight: CGFloat) {
        self.isPlaying = isPlaying
        self.speed = speed
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        _height = State(initialValue: minHeight)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.appPurple)
            .frame(width: 3, height: height)
            .onAppear {
                if isPlaying {
                    startAnimation()
                }
            }
            .onChange(of: isPlaying) { oldValue, newValue in
                if newValue {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
    }

    private func startAnimation() {
        withAnimation(
            Animation.easeInOut(duration: speed)
                .repeatForever(autoreverses: true)
        ) {
            height = maxHeight
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            height = minHeight
        }
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
