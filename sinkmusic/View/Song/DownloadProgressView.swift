//
//  DownloadProgressView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Vista de progreso de descarga
struct DownloadProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                // Fondo blanco
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 100, height: 4)
                    .cornerRadius(2)

                // Progreso amarillo
                Rectangle()
                    .fill(Color.appPurple)
                    .frame(width: 100 * progress, height: 4)
                    .cornerRadius(2)
                    .animation(.linear(duration: 1.0), value: progress)
            }

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(width: 100)
    }
}
