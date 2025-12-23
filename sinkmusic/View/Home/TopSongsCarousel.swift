//
//  TopSongsCarousel.swift
//  sinkmusic
//
//  Created by miguel tomairo

import SwiftUI

struct TopSongsCarousel: View {
    let songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Canciones que más escuchas")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            if songs.isEmpty {
                EmptyTopSongsView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(songs) { song in
                            TopSongCard(song: song)
                                .onTapGesture {
                                    if let url = song.localURL {
                                        playerViewModel.play(song: song, from: url, in: songs)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct TopSongCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            ZStack {
                if let artworkData = song.artworkData,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
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
                .frame(width: 120, alignment: .leading)

            // Artist
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(.textGray)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .frame(width: 120)
    }
}

struct EmptyTopSongsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundColor(.textGray)

            Text("Aún no tienes historial")
                .font(.system(size: 14))
                .foregroundColor(.textGray)

            Text("Reproduce canciones para verlas aquí")
                .font(.system(size: 12))
                .foregroundColor(.textGray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
