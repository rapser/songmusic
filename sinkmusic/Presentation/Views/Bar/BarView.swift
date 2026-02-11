//
//  BarView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct BarView: View {
    let isPlaying: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let delay: Double

    @State private var targetHeight: CGFloat
    @State private var animationTask: Task<Void, Never>?

    init(isPlaying: Bool, minHeight: CGFloat, maxHeight: CGFloat, delay: Double = 0) {
        self.isPlaying = isPlaying
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.delay = delay
        _targetHeight = State(initialValue: minHeight)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.appPurple)
            .frame(width: 3, height: targetHeight)
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
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private func startAnimation() {

        // Cancel any existing animation
        animationTask?.cancel()

        // Start new animation task
        animationTask = Task { @MainActor [self] in
            // Initial delay if specified
            if delay > 0 {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            }
            
            guard !Task.isCancelled else { return }
            
            // Animate to random height immediately
            animateToRandomHeight()
            
            // Continue animating while playing
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled && isPlaying else { break }
                animateToRandomHeight()
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            targetHeight = minHeight
        }
    }

    private func animateToRandomHeight() {
        let randomHeight = CGFloat.random(in: minHeight...maxHeight)
        withAnimation(.easeInOut(duration: 0.15)) {
            targetHeight = randomHeight
        }
    }
}
