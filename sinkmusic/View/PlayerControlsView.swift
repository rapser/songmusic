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

    private var progress: Double {
        guard playerViewModel.songDuration > 0 else { return 0 }
        return playerViewModel.playbackTime / playerViewModel.songDuration
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Contenido principal del mini player
            HStack(spacing: 4) {
                MiniPlayerArtwork(
                    artworkData: song.artworkData,
                    cachedImage: playerViewModel.cachedArtwork
                )

                MiniPlayerInfo(title: song.title, artist: song.artist)

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
        .onAppear {
            if song.cachedDominantColorRed == nil {
                Task(priority: .utility) {
                    Color.cacheAndGetDominantColor(for: song)
                }
            }
        }
    }
}

// MARK: - Componentes Modulares del MiniPlayer

/// Artwork del miniplayer (42x42)
private struct MiniPlayerArtwork: View {
    let artworkData: Data?
    let cachedImage: UIImage?

    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
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
    }
}

/// Información de la canción en el miniplayer
private struct MiniPlayerInfo: View {
    let title: String
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(artist)
                .font(.system(size: 12))
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .drawingGroup()
    }
}

/// Botón de play/pause del miniplayer
private struct MiniPlayerPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.appPurple)
                .cornerRadius(16)
        }
    }
}

/// Barra de progreso del miniplayer
private struct MiniPlayerProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)

                Rectangle()
                    .fill(Color.white)
                    .frame(
                        width: geometry.size.width * progress,
                        height: 2
                    )
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
        .drawingGroup()
    }
}

/// Background del miniplayer con color dominante
private struct MiniPlayerBackground: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.2))
            )
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
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
