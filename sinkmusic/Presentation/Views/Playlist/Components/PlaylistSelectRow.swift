//
//  PlaylistSelectRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct PlaylistSelectRow: View {
    let playlist: PlaylistUI
    let song: SongUI
    let isAdded: Bool

    @State private var cachedImage: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Cover Image
            ZStack {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(4)
                } else if playlist.coverImageData != nil {
                    Color.appGray
                        .frame(width: 50, height: 50)
                        .cornerRadius(4)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        )
                } else {
                    let (c1, c2) = PlaylistPlaceholderColors.gradient(for: playlist)
                    LinearGradient(
                        gradient: Gradient(colors: [c1, c2]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }

            // Playlist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(playlist.songCount) canciones")
                    .font(.system(size: 13))
                    .foregroundColor(.textGray)
            }

            Spacer()

            // Checkmark if already added
            if isAdded {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPurple)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.clear)
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
    }
}
