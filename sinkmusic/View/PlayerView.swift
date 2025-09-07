import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel // Keep MainViewModel for isScrolling
    @EnvironmentObject var playerViewModel: PlayerViewModel // New EnvironmentObject
    var songs: [Song]
    var currentSong: Song
    var namespace: Namespace.ID
    // Removed @Binding var showPlayerView: Bool
    
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
                            playerViewModel.showPlayerView = false // Use playerViewModel
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
                    Slider(value: $sliderValue, in: 0...(playerViewModel.songDuration > 0 ? playerViewModel.songDuration : 1)) { editing in
                        isEditingSlider = editing
                        if !editing {
                            playerViewModel.seek(to: sliderValue)
                        }
                    }
                    .accentColor(.spotifyGreen)
                    
                    HStack {
                        Text(playerViewModel.formatTime(playerViewModel.playbackTime)) // Use playerViewModel
                        Spacer()
                        Text(playerViewModel.formatTime(playerViewModel.songDuration)) // Use playerViewModel
                    }
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
                }
                .padding(.horizontal)
                
                // Controles de reproducción
                HStack(spacing: 50) {
                    Button(action: { playerViewModel.playPrevious(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { playerViewModel.play(song: currentSong) }) {
                        Image(playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { playerViewModel.playNext(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear { sliderValue = playerViewModel.playbackTime } // Use playerViewModel
        .onChange(of: playerViewModel.playbackTime) { _, newValue in
            if !isEditingSlider {
                sliderValue = newValue
            }
        }
    }
}
