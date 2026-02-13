//
//  SongInfoView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Componente optimizado para mostrar la información de la canción.
/// Estilo tipo Spotify: icono play/pausa a la izquierda, tap en la fila = reproducir.
struct SongInfoView: View {
    let title: String
    let artist: String
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icono tipo Spotify: play para el resto, waveform/pausa para la actual
            ZStack {
                if isCurrentlyPlaying {
                    Image(systemName: isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.appPurple)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: isPlaying)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textGray)
                }
            }
            .frame(width: 28, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isCurrentlyPlaying ? .appPurple : .white)
                    .lineLimit(1)

                Text(artist)
                    .font(.subheadline)
                    .foregroundColor(.textGray)
                    .lineLimit(1)
            }
        }
    }
}
