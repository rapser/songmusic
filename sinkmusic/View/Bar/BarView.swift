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
    @State private var animationTimer: Timer?

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
                animationTimer?.invalidate()
                animationTimer = nil
            }
    }

    private func startAnimation() {
        // Iniciar con un delay si se especifica
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.isPlaying else { return }
            self.animateToRandomHeight()
            // Configurar timer para cambiar alturas periódicamente
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                guard self.isPlaying else { return }
                self.animateToRandomHeight()
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
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
