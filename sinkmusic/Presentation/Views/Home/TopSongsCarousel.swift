//
//  TopSongsCarousel.swift
//  sinkmusic
//
//  Created by miguel tomairo

import SwiftUI

struct TopSongsCarousel: View {
    let songs: [SongEntity]
    @Environment(PlayerViewModel.self) private var playerViewModel

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
                                    Task {
                                        await playerViewModel.play(songID: song.id, queue: songs)
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
