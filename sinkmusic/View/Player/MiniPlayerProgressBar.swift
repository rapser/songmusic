//
//  MiniPlayerProgressBar.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Barra de progreso del miniplayer
struct MiniPlayerProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)

                Rectangle()
                    .fill(Color.white)
                    .frame(
                        width: geometry.size.width * progress,
                        height: 2
                    )
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
        .drawingGroup()
    }
}
