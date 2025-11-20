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
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Contenido principal del mini player
            HStack(spacing: 12) {
                // Icono de la canción
                ZStack {
                    Color.spotifyGreen
                        .frame(width: 42, height: 42)
                        .cornerRadius(8)

                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white)
                }

                // Información de la canción
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.spotifyLightGray)
                        .lineLimit(1)
                }
                .padding(.leading, 8)

                Spacer()

                // Botón de play/pause
                Button(action: { playerViewModel.play(song: song) }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.spotifyGreen)
                        .cornerRadius(16)
                }
            }
            .padding(12)
            .padding(.bottom, 4)

            // Barra de progreso estilo Spotify
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo de la barra (gris oscuro)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 2)

                    // Progreso (verde)
                    Rectangle()
                        .fill(Color.spotifyGreen)
                        .frame(
                            width: geometry.size.width * progress,
                            height: 2
                        )
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
            .padding(.bottom, 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.spotifyGray)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        )
        .matchedGeometryEffect(id: "player", in: namespace)
    }

    // Computed property para calcular el progreso
    private var progress: Double {
        guard playerViewModel.songDuration > 0 else { return 0 }
        return playerViewModel.playbackTime / playerViewModel.songDuration
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        playerVM: PreviewViewModels.playerVM(songID: PreviewSongs.single().id)
    ) {
        PlayerControlsView(song: PreviewSongs.single(), namespace: Namespace().wrappedValue)
    }
}
