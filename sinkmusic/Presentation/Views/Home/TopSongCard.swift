//
//  TopSongCard.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//


import SwiftUI

struct TopSongCard: View {
    let song: SongUIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            ZStack {
                if let artworkData = song.artworkThumbnail,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 155)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 155)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
            .cornerRadius(8)

            // Title
            Text(song.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            // Artist
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(.textGray)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
        }
        .frame(width: 150)
    }
}
