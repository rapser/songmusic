//
//  SearchResultsList.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//  Refactored to Clean Architecture
//

import SwiftUI

struct SearchResultsList: View {
    let songs: [SongUI]
    @Environment(PlayerViewModel.self) private var playerViewModel

    @State private var displayedCount = 50
    private let pageSize = 30

    private var displayedSongs: [SongUI] {
        Array(songs.prefix(displayedCount))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayedSongs) { song in
                    SearchResultRow(
                        song: song,
                        currentlyPlayingID: playerViewModel.currentlyPlayingID,
                        isPlaying: playerViewModel.isPlaying,
                        onTap: {
                            Task {
                                await playerViewModel.play(songID: song.id, queue: songs)
                            }
                        }
                    )
                    .id(song.id)
                }

                if displayedCount < songs.count {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            displayedCount = min(displayedCount + pageSize, songs.count)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .onChange(of: songs.first?.id) {
            displayedCount = 50
        }
    }
}
