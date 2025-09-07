//
//  PlayerControlsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct PlayerControlsView: View {
    let song: Song
    var namespace: Namespace.ID
    @EnvironmentObject var viewModel: MainViewModel // Keep MainViewModel for isScrolling
    @EnvironmentObject var playerViewModel: PlayerViewModel // New EnvironmentObject

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color.spotifyGreen
                    .frame(width: 50, height: 50)
                    .opacity(0.7)
                    .cornerRadius(12)

                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.spotifyLightGray)
            }
            .padding(.leading, 12)

            Spacer()

            Button(action: { playerViewModel.play(song: song) }) { // Use playerViewModel
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill") // Use playerViewModel
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .padding(.horizontal)
        .background(Color(red: 50/255, green: 50/255, blue: 50/255).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .matchedGeometryEffect(id: "player", in: namespace)
    }
}

#Preview {
    PlayerControlsViewPreviewWrapper()
}

private struct PlayerControlsViewPreviewWrapper: View {
    @Namespace private var namespace

    var body: some View {
        let exampleSong = Song(
            id: UUID(),
            title: "Song 1",
            artist: "Artist 1",
            fileID: "file1",
            isDownloaded: false
        )

        // Instancias de ViewModels de prueba
        let mainViewModel = MainViewModel()
        let playerViewModel = PlayerViewModel()
        playerViewModel.isPlaying = true

        return PlayerControlsView(
            song: exampleSong,
            namespace: namespace
        )
        .environmentObject(mainViewModel)
        .environmentObject(playerViewModel)
        .padding()
        .background(Color.black.ignoresSafeArea()) // Fondo oscuro
    }
}
