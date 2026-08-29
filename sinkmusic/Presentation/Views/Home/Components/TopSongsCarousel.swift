//
//  TopSongsCarousel.swift
//  sinkmusic
//
//  Created by miguel tomairo

import SwiftUI

struct TopSongsCarousel: View {
    let songs: [SongUI]
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel

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
                                        await playerViewModel.play(
                                            songID: song.id,
                                            queue: queueForPlayback(of: song)
                                        )
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    /// Al tocar una canción del ranking, la cola de reproducción es su playlist de origen
    /// —NO el propio ranking—: así, al terminar la canción, sigue sonando la playlist a la
    /// que pertenece y no se encadena "las más escuchadas". Si la canción no está en
    /// ninguna playlist, la cola es solo esa canción (suena únicamente ella).
    private func queueForPlayback(of song: SongUI) -> [SongUI] {
        playlistViewModel.playlists
            .first { $0.songs.contains { $0.id == song.id } }
            .map(\.songs) ?? [song]
    }
}
