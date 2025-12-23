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
                    HStack(spacing: 14) {
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
