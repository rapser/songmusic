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
        HStack(spacing: 12) {
            // Icono de la canción
            ZStack {
                Color.spotifyGreen
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)

                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
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
                    .frame(width: 15, height: 15)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.spotifyGreen)
                    .cornerRadius(16)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 40/255, green: 40/255, blue: 40/255))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .matchedGeometryEffect(id: "player", in: namespace)
        .opacity(0.7)
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
