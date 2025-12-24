//
//  PlayerSongInfo.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Información de la canción (título y artista)
struct PlayerSongInfo: View {
    let title: String
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarqueeText(text: title, font: .system(size: 24, weight: .bold), color: .white)

            Text(artist)
                .font(.system(size: 18))
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
