//
//  BarView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

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