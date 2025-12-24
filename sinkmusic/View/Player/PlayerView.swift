import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var metadataViewModel: MetadataCacheViewModel
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
                        // Sin animación - cerrar instantáneamente
                        playerViewModel.showPlayerView = false
                    }
                )

                // Artwork de la canción
                PlayerArtwork(
                    artworkData: currentSong.artworkData,
                    cachedImage: metadataViewModel.cachedArtwork,
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
                    // Si desliza más de 150 puntos, cerrar el player instantáneamente
                    if value.translation.height > 150 {
                        playerViewModel.showPlayerView = false
                    }
                    // Resetear el offset instantáneamente
                    dragOffset = 0
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
            // Solo actualizar si no está buscando manualmente Y si el cambio es significativo (> 0.5 segundos)
            // Esto previene actualizaciones excesivas por frame
            if !isSeekingManually && abs(newValue - sliderValue) > 0.5 {
                sliderValue = newValue
            }
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
        }
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
