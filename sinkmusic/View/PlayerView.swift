import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    var songs: [Song]
    var currentSong: Song
    var namespace: Namespace.ID

    @State private var sliderValue: Double = 0
    @State private var isSeekingManually = false
    @State private var showEqualizer = false
    @State private var dragOffset: CGFloat = 0

    private var dominantColor: Color {
        Color.dominantColor(from: currentSong)
    }

    var body: some View {
        ZStack {
            // Background con color dominante
            PlayerBackground(color: dominantColor)

            VStack(spacing: 12) {
                // Header
                PlayerHeader(
                    showEqualizer: $showEqualizer,
                    onClose: {
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0)) {
                            playerViewModel.showPlayerView = false
                        }
                    }
                )

                // Artwork de la canción
                PlayerArtwork(
                    artworkData: currentSong.artworkData,
                    namespace: namespace
                )

                // Título y artista
                PlayerSongInfo(
                    title: currentSong.title,
                    artist: currentSong.artist
                )

                // Slider y tiempos
                PlayerTimeControls(
                    sliderValue: $sliderValue,
                    isSeekingManually: $isSeekingManually,
                    currentTime: playerViewModel.playbackTime,
                    duration: playerViewModel.songDuration,
                    formatTime: playerViewModel.formatTime,
                    onSeek: { time in
                        playerViewModel.seek(to: time)
                    }
                )

                // Controles de reproducción
                PlayerControls(
                    isPlaying: playerViewModel.isPlaying,
                    isShuffleEnabled: playerViewModel.isShuffleEnabled,
                    repeatMode: playerViewModel.repeatMode,
                    onToggleShuffle: { playerViewModel.toggleShuffle() },
                    onPrevious: { playerViewModel.playPrevious(currentSong: currentSong, allSongs: songs) },
                    onPlayPause: { playerViewModel.togglePlayPause() },
                    onNext: { playerViewModel.playNext(currentSong: currentSong, allSongs: songs) },
                    onToggleRepeat: { playerViewModel.toggleRepeat() }
                )

                Spacer()
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Solo permitir deslizar hacia abajo
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    // Si desliza más de 150 puntos, cerrar el player
                    if value.translation.height > 150 {
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0)) {
                            playerViewModel.showPlayerView = false
                        }
                    }
                    // Resetear el offset con animación
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0)) {
                        dragOffset = 0
                    }
                }
        )
        .onAppear {
            sliderValue = playerViewModel.playbackTime
            if currentSong.cachedDominantColorRed == nil {
                Task(priority: .utility) {
                    Color.cacheAndGetDominantColor(for: currentSong)
                }
            }
        }
        .onChange(of: currentSong.id) { oldValue, newValue in
            sliderValue = 0
            isSeekingManually = false
        }
        .onChange(of: playerViewModel.playbackTime) { oldValue, newValue in
            if !isSeekingManually {
                sliderValue = newValue
            }
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
        }
    }
}

// MARK: - Componentes Modulares del Player

/// Background del player con gradiente
private struct PlayerBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            color.ignoresSafeArea(.all)

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
        }
    }
}

/// Header del player con botones
private struct PlayerHeader: View {
    @Binding var showEqualizer: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: { showEqualizer = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

/// Artwork grande del player
private struct PlayerArtwork: View {
    let artworkData: Data?
    var namespace: Namespace.ID

    var body: some View {
        Group {
            if let artworkData = artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appPurple)
                        .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)

                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 16)
        .matchedGeometryEffect(id: "player", in: namespace)
        .padding(.bottom, 30)
    }
}

/// Información de la canción (título y artista)
private struct PlayerSongInfo: View {
    let title: String
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(artist)
                .font(.system(size: 18))
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .drawingGroup()
    }
}

/// Controles de tiempo (slider y labels)
private struct PlayerTimeControls: View {
    @Binding var sliderValue: Double
    @Binding var isSeekingManually: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let formatTime: (TimeInterval) -> String
    let onSeek: (Double) -> Void

    var body: some View {
        VStack {
            Slider(
                value: $sliderValue,
                in: 0...(duration > 0 ? duration : 1),
                onEditingChanged: { editing in
                    isSeekingManually = editing
                    if !editing {
                        onSeek(sliderValue)
                    }
                }
            )
            .accentColor(.white)

            HStack {
                Text(formatTime(isSeekingManually ? sliderValue : currentTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption)
            .foregroundColor(.textGray)
        }
        .padding(.horizontal, 20)
    }
}

/// Controles de reproducción (shuffle, prev, play, next, repeat)
private struct PlayerControls: View {
    let isPlaying: Bool
    let isShuffleEnabled: Bool
    let repeatMode: PlayerViewModel.RepeatMode
    let onToggleShuffle: () -> Void
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onToggleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button(action: onToggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(isShuffleEnabled ? .appPurple : .textGray)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Previous
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Play/Pause
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
            }

            Spacer()

            // Next
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Repeat
            Button(action: onToggleRepeat) {
                Image(systemName: repeatMode == .repeatOne ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundColor(repeatMode != .off ? .appPurple : .textGray)
                    .frame(width: 50, height: 50)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(songID: PreviewSongs.generate().first!.id)
    ) {
        PlayerView(
            songs: PreviewSongs.generate(downloaded: true),
            currentSong: PreviewSongs.generate(downloaded: true).first!,
            namespace: Namespace().wrappedValue
        )
    }
}
