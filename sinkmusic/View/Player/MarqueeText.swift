//
//  MarqueeText.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Componente de texto con efecto marquee (scroll automático para textos largos)
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var shouldAnimate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Texto para medir el ancho
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear.onAppear {
                                textWidth = textGeometry.size.width
                                containerWidth = geometry.size.width
                                shouldAnimate = textWidth > containerWidth
                            }
                        }
                    )
                    .offset(x: shouldAnimate ? offset : 0)

                // Texto duplicado para efecto continuo (solo si es necesario)
                if shouldAnimate {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .fixedSize()
                        .offset(x: offset + textWidth + 30) // 30px de espacio entre repeticiones
                }
            }
            .clipped()
            .onAppear {
                if shouldAnimate {
                    startAnimation()
                }
            }
            .onChange(of: text) { oldValue, newValue in
                // Reiniciar animación cuando cambia el texto
                offset = 0
                shouldAnimate = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if textWidth > containerWidth {
                        shouldAnimate = true
                        startAnimation()
                    }
                }
            }
        }
        .frame(height: font == .system(size: 24, weight: .bold) ? 30 : 24)
    }

    private func startAnimation() {
        guard shouldAnimate else { return }

        // Pausar 2 segundos antes de empezar
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(
                .linear(duration: Double(textWidth) / 30) // Velocidad constante
                    .repeatForever(autoreverses: false)
            ) {
                offset = -(textWidth + 30)
            }
        }
    }
}
