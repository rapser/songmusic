//
//  SearchResultsList.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct SearchResultsList: View {
    let songs: [Song]
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(songs) { song in
                    SearchResultRow(
                        song: song,
                        currentlyPlayingID: playerViewModel.currentlyPlayingID,
                        isPlaying: playerViewModel.isPlaying,
                        onTap: {
                            if let url = song.localURL {
                                playerViewModel.play(song: song, from: url, in: songs)
                            }
                        }
                    )
                    .equatable() // Usar Equatable para evitar re-renderizados innecesarios
                    .id(song.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}
