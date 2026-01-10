//
//  SearchResultsList.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//  Refactored to Clean Architecture
//

import SwiftUI

struct SearchResultsList: View {
    let songs: [SongUIModel]
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(songs) { song in
                    SearchResultRow(
                        song: song,
                        currentlyPlayingID: playerViewModel.currentlyPlayingID,
                        isPlaying: playerViewModel.isPlaying,
                        onTap: {
                            Task {
                                // TODO: PlayerViewModel.play needs updating to accept [SongUIModel]
                                // await playerViewModel.play(songID: song.id, queue: songs)
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
