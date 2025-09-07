import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel
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
                }.padding()

                Image(systemName: "music.note")
                    .font(.system(size: 200))
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .foregroundColor(.white)

                VStack {
                    Text(currentSong.title).font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text(currentSong.artist).font(.title2).foregroundColor(.spotifyLightGray)
                }

                VStack {
                    Slider(value: $sliderValue, in: 0...(viewModel.songDuration > 0 ? viewModel.songDuration : 1)) { editing in
                        isEditingSlider = editing
                        if !editing {
                            viewModel.seek(to: sliderValue)
                        }
                    }
                    .accentColor(.spotifyGreen)
                    
                    HStack {
                        Text(formatTime(viewModel.playbackTime))
                        Spacer()
                        Text(formatTime(viewModel.songDuration))
                    }
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
                }.padding(.horizontal)

                HStack(spacing: 40) {
                    Button(action: { viewModel.playPrevious(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "backward.fill").font(.largeTitle)
                    }
                    Button(action: { viewModel.play(song: currentSong) }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                    }
                    Button(action: { viewModel.playNext(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "forward.fill").font(.largeTitle)
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
            }
        }
        .matchedGeometryEffect(id: "player", in: namespace)
        .onAppear {
            sliderValue = viewModel.playbackTime
        }
        .onChange(of: viewModel.playbackTime) { _, newValue in
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
        // Crear canciones de ejemplo
        let exampleSongs = [
            Song(id: UUID(), title: "Song 1", artist: "Artist 1", fileID: "file1", isDownloaded: false),
            Song(id: UUID(), title: "Song 2", artist: "Artist 2", fileID: "file2", isDownloaded: false)
        ]
        
        // Instancia del ViewModel de prueba
        let viewModel = MainViewModel()
        viewModel.songDuration = 240  // 4 minutos
        viewModel.playbackTime = 60   // 1 minuto de reproducción
        viewModel.isPlaying = true

        return PlayerView(
            songs: exampleSongs,
            currentSong: exampleSongs[0],
            namespace: namespace,
            showPlayerView: .constant(true)
        )
        .environmentObject(viewModel)
    }
}

