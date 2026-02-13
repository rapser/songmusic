//
//  PlaylistCardView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 21/12/25.
//  Refactored to Clean Architecture - Uses PlaylistUI
//

import SwiftUI

struct PlaylistCardView: View {
    let playlist: PlaylistUI
    @State private var cachedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            ZStack {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipped()
                } else if playlist.coverImageData != nil {
                    // Mostrar placeholder mientras carga
                    Color.appGray
                        .frame(width: 160, height: 160)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                } else {
                    let (c1, c2) = PlaylistPlaceholderColors.gradient(for: playlist)
                    LinearGradient(
                        gradient: Gradient(colors: [c1, c2]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 160, height: 160)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(8)
            .task(id: playlist.id) {
                // Cargar imagen en background para no bloquear el audio
                if let coverData = playlist.coverImageData, cachedImage == nil {
                    await Task.detached(priority: .userInitiated) {
                        let image = UIImage(data: coverData)
                        await MainActor.run {
                            cachedImage = image
                        }
                    }.value
                }
            }

            // Playlist Info
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(playlist.songCount) canciones")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textGray)
            }
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
