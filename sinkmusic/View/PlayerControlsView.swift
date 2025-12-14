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
    
    private var dominantColor: Color {
        Color.dominantColor(from: song)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Contenido principal del mini player
            HStack(spacing: 4) {
                // Icono de la canción
                Group {
                    if let artworkData = song.artworkData,
                       let uiImage = UIImage(data: artworkData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        ZStack {
                            Color.appPurple
                                .frame(width: 42, height: 42)
                                .cornerRadius(4)

                            Image(systemName: "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                }

                // Información de la canción
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.textGray)
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
                        .background(Color.appPurple)
                        .cornerRadius(16)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Barra de progreso estilo Spotify - 2px desde el bottom, 10px horizontal
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo de la barra (gris oscuro)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 2)

                    // Progreso (verde)
                    Rectangle()
                        .fill(Color.appPurple)
                        .frame(
                            width: geometry.size.width * progress,
                            height: 2
                        )
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
        }
        .frame(height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dominantColor.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.2))
                )
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        )
        .matchedGeometryEffect(id: "player", in: namespace)
        .onAppear {
            // Cachear color si no está cacheado
            if song.cachedDominantColorRed == nil {
                Task.detached(priority: .userInitiated) {
                    _ = await MainActor.run {
                        Color.cacheAndGetDominantColor(for: song)
                    }
                }
            }
        }
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
