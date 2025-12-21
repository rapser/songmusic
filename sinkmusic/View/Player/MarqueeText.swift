//
//  MarqueeText.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Componente de texto con efecto marquee usando animación lineal nativa
/// Movimiento fluido sin saltos usando Core Animation
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false

    private var needsScrolling: Bool {
        textWidth > containerWidth && textWidth > 0 && containerWidth > 0
    }

    private let spacing: CGFloat = 40
    private let speed: CGFloat = 30.0 // píxeles por segundo

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Texto principal
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .preference(key: WidthPreferenceKey.self, value: textGeometry.size.width)
                        }
                    )
                    .offset(x: offset)

                // Texto duplicado para loop continuo
                if needsScrolling {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .fixedSize()
                        .offset(x: offset + textWidth + spacing)
                }
            }
            .clipped()
            .drawingGroup() // GPU rendering para máxima fluidez
            .onPreferenceChange(WidthPreferenceKey.self) { width in
                textWidth = width
                containerWidth = geometry.size.width

                // Reiniciar animación si cambia el tamaño
                if needsScrolling && !isAnimating {
                    startScrolling()
                }
            }
            .onChange(of: text) { _, _ in
                // Reset completo cuando cambia el texto
                isAnimating = false
                offset = 0
            }
            .onAppear {
                if needsScrolling {
                    startScrolling()
                }
            }
            .onDisappear {
                isAnimating = false
            }
        }
        .frame(height: font == .system(size: 24, weight: .bold) ? 30 : 24)
    }

    private func startScrolling() {
        guard needsScrolling, !isAnimating else { return }

        isAnimating = true
        offset = 0

        // Delay mínimo para dar tiempo a leer el inicio
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard isAnimating else { return }
            animateScroll()
        }
    }

    private func animateScroll() {
        let totalDistance = textWidth + spacing
        let duration = Double(totalDistance / speed)

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalDistance
        }
    }
}

// PreferenceKey para obtener el ancho del texto
private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
