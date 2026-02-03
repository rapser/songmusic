import SwiftUI

struct PlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(MetadataCacheViewModel.self) private var metadataViewModel
    var songs: [SongUI]
    var currentSong: SongUI
    var namespace: Namespace.ID

    @State private var sliderValue: Double = 0
    @State private var isSeekingManually = false
    @State private var showEqualizer = false
    @State private var dragOffset: CGFloat = 0

    private var dominantColor: Color {
        currentSong.backgroundColor
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
                    artworkData: currentSong.artworkThumbnail,
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
                        Task {await playerViewModel.seek(to: time)}
                    }
                )

                // Controles de reproducción
                PlayerControls(
                    isPlaying: playerViewModel.isPlaying,
                    isShuffleEnabled: playerViewModel.isShuffleEnabled,
                    repeatMode: playerViewModel.repeatMode,
                    onToggleShuffle: { playerViewModel.toggleShuffle() },
                    onPrevious: { Task { await playerViewModel.playPrevious() } },
                    onPlayPause: { Task { await playerViewModel.togglePlayPause() } },
                    onNext: { Task { await playerViewModel.playNext() } },
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
            // El color dominante se calcula automáticamente cuando se necesita
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

//#Preview {
//    PreviewWrapper(
//        playerVM: PreviewViewModels.playerVM(songID: PreviewSongs.generate().first!.id)
//    ) {
//        PlayerView(
//            songs: PreviewSongs.generate(downloaded: true),
//            currentSong: PreviewSongs.generate(downloaded: true).first!,
//            namespace: Namespace().wrappedValue
//        )
//    }
//}
