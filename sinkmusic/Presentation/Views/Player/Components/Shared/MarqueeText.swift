//
//  MarqueeText.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// GeometryEffect personalizado para animación de marquee fluida
struct MarqueeEffect: GeometryEffect {
    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Usar translación directa para máxima fluidez
        let transform = CGAffineTransform(translationX: offset, y: 0)
        return ProjectionTransform(transform)
    }
}

/// Componente de texto con efecto marquee usando GeometryEffect
/// Movimiento perfectamente fluido como Spotify
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animationOffset: CGFloat = 0
    @State private var isAnimating = false

    private var needsScrolling: Bool {
        textWidth > containerWidth && textWidth > 0 && containerWidth > 0
    }

    private let spacing: CGFloat = 40
    private let speed: CGFloat = 30.0

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: font == .system(size: 24, weight: .bold) ? 30 : 24)
    }

    private func startScrolling() {
        guard needsScrolling, !isAnimating else { return }

        isAnimating = true
        animationOffset = 0

        // Iniciar animación inmediatamente
        animateScroll()
    }

    private func animateScroll() {
        let totalDistance = textWidth + spacing
        let duration = Double(totalDistance / speed)

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            animationOffset = -totalDistance
        }
    }
}

// PreferenceKey para obtener el ancho del texto
private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
