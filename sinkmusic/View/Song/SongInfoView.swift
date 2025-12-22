//
//  SongInfoView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Componente optimizado para mostrar la información de la canción
struct SongInfoView: View {
    let title: String
    let artist: String
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isCurrentlyPlaying {
                    // TODO: - Corregir
//                    PlayingBarsIndicator(isPlaying: isPlaying)
                    Image(systemName: "waveform")
                        .foregroundColor(.appPurple)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(isCurrentlyPlaying ? .appPurple : .white)
                    .lineLimit(1)
            }

            Text(artist)
                .font(.subheadline)
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        
    }
}
