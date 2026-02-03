//
//  PendingSongsListView.swift
//  sinkmusic
//
//  Lista de canciones pendientes de descarga
//

import SwiftUI

struct PendingSongsListView: View {
    let pendingSongs: [SongUI]
    let playerViewModel: PlayerViewModel
    @Binding var songForPlaylistSheet: SongUI?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            songsList
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Text("\(pendingSongs.count) canciones por descargar")
                .font(.subheadline)
                .foregroundColor(.textGray)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(pendingSongs) { song in
                    songRow(for: song)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func songRow(for song: SongUI) -> some View {
        SongRow(
            song: song,
            songQueue: pendingSongs,
            isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
            isPlaying: playerViewModel.isPlaying,
            onPlay: {
                Task {
                    await playerViewModel.play(songID: song.id, queue: pendingSongs)
                }
            },
            onPause: {
                Task {
                    await playerViewModel.pause()
                }
            },
            showAddToPlaylistForSong: $songForPlaylistSheet
        )
    }
}
