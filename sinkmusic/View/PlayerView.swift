import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    var songs: [Song]
    var currentSong: Song
    var namespace: Namespace.ID
    @Binding var showPlayerView: Bool

    @State private var sliderValue: Double = 0
    @State private var isEditingSlider = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.spotifyGray, Color.spotifyBlack]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 32) {
                // Header con botón cerrar
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showPlayerView = false
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()

                // Imagen de la canción
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "player", in: namespace)

                // Título y artista
                VStack(spacing: 4) {
                    Text(currentSong.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(currentSong.artist)
                        .font(.title2)
                        .foregroundColor(.spotifyLightGray)
                        .lineLimit(1)
                }

                // Slider de progreso
                VStack {
                    Slider(value: $sliderValue, in: 0...(playerViewModel.songDuration > 0 ? playerViewModel.songDuration : 1)) { editing in // Use playerViewModel
                        isEditingSlider = editing
                        if !editing {
                            playerViewModel.seek(to: sliderValue) // Use playerViewModel
                        }
                    }
                    .accentColor(.spotifyGreen)

                    HStack {
                        Text(formatTime(playerViewModel.playbackTime)) // Use playerViewModel
                        Spacer()
                        Text(formatTime(playerViewModel.songDuration)) // Use playerViewModel
                    }
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
                }
                .padding(.horizontal)

                // Controles de reproducción
                HStack(spacing: 50) {
                    Button(action: { playerViewModel.playPrevious(currentSong: currentSong, allSongs: songs) }) { // Use playerViewModel
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }

                    Button(action: { playerViewModel.play(song: currentSong) }) { // Use playerViewModel
                        Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill") // Use playerViewModel
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }

                    Button(action: { playerViewModel.playNext(currentSong: currentSong, allSongs: songs) }) { // Use playerViewModel
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
        }
        .onAppear { sliderValue = playerViewModel.playbackTime } // Use playerViewModel
        .onChange(of: playerViewModel.playbackTime) { _, newValue in // Use playerViewModel
            if !isEditingSlider {
                sliderValue = newValue
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayerViewPreviewWrapper()
}

private struct PlayerViewPreviewWrapper: View {
    @Namespace private var namespace
    
    var body: some View {
        let exampleSongs = [
            Song(id: UUID(), title: "Song 1", artist: "Artist 1", fileID: "file1", isDownloaded: false),
            Song(id: UUID(), title: "Song 2", artist: "Artist 2", fileID: "file2", isDownloaded: false)
        ]
        
        // Instancias de ViewModels de prueba
        let mainViewModel = MainViewModel()
        let playerViewModel = PlayerViewModel()
        
        // Estado inicial simulado
        playerViewModel.songDuration = 240   // 4 minutos
        playerViewModel.playbackTime = 60    // 1 minuto de reproducción
        playerViewModel.isPlaying = true

        return PlayerView(
            songs: exampleSongs,
            currentSong: exampleSongs[0],
            namespace: namespace,
            showPlayerView: .constant(true)
        )
        .environmentObject(mainViewModel)
        .environmentObject(playerViewModel)
    }
}
