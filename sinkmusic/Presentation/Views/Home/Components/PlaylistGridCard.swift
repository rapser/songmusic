//
//  PlaylistGridCard.swift
//  sinkmusic
//
//  Tarjeta compacta de playlist para grid
//

import SwiftUI

struct PlaylistGridCard: View {
    let playlist: PlaylistUIModel

    var body: some View {
        HStack(spacing: 8) {
            // Cover image - 50x50
            ZStack {
                if let coverData = playlist.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.6, brightness: 0.5),
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.7, brightness: 0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(4)

            // Playlist name - centrado verticalmente
            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 50)
        .background(Color.white.opacity(0.1))
        .cornerRadius(4)
    }
}
