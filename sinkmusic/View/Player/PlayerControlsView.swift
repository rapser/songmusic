//
//  PlayerControlsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct PlayerControlsView: View {
    let songID: UUID
    let title: String
    let artist: String
    let dominantColor: Color
    var namespace: Namespace.ID
    @EnvironmentObject var playerViewModel: PlayerViewModel

    private var progress: Double {
        guard playerViewModel.songDuration > 0 else { return 0 }
        return playerViewModel.playbackTime / playerViewModel.songDuration
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Contenido principal del mini player
            HStack(spacing: 4) {
                MiniPlayerArtwork(
                    cachedImage: playerViewModel.cachedArtwork
                )

                MiniPlayerInfo(title: title, artist: artist)

                Spacer()

                MiniPlayerPlayButton(
                    isPlaying: playerViewModel.isPlaying,
                    action: { playerViewModel.togglePlayPause() }
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Barra de progreso
            MiniPlayerProgressBar(progress: progress)
        }
        .frame(height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(
            MiniPlayerBackground(color: dominantColor)
        )
        .matchedGeometryEffect(id: "player", in: namespace)
    }
}

#Preview {
    let song = PreviewSongs.single()
    return PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(songID: song.id)
    ) {
        PlayerControlsView(
            songID: song.id,
            title: song.title,
            artist: song.artist,
            dominantColor: .appPurple,
            namespace: Namespace().wrappedValue
        )
    }
}
