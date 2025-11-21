import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    var songs: [Song]
    var currentSong: Song
    var namespace: Namespace.ID
    
    @State private var sliderValue: Double = 0
    @State private var isEditingSlider = false
    @State private var showEqualizer = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.spotifyGray, Color.spotifyBlack]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 12) {
                // Header con botón cerrar y ecualizador
                HStack {
                    Button(action: { showEqualizer = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            playerViewModel.showPlayerView = false
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // Imagen de la canción
                Group {
                    if let artworkData = currentSong.artworkData,
                       let uiImage = UIImage(data: artworkData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 360)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 10)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.spotifyGreen)
                                .frame(height: 360)

                            Image(systemName: "music.note")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 190, height: 190)
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 10)
                    }
                }
//                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .matchedGeometryEffect(id: "player", in: namespace)
                .padding(.bottom, 30)
                
                // Título y artista (alineados a la izquierda)
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSong.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(currentSong.artist)
                        .font(.system(size: 18))
                        .foregroundColor(.spotifyLightGray)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
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
                        Text(playerViewModel.formatTime(playerViewModel.playbackTime))
                        Spacer()
                        Text(playerViewModel.formatTime(playerViewModel.songDuration))
                    }
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
                }
                .padding(.horizontal, 16)
                
                // Controles de reproducción con shuffle y repeat en la misma línea
                HStack(spacing: 0) {
                    // Shuffle
                    Button(action: { playerViewModel.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(playerViewModel.isShuffleEnabled ? .spotifyGreen : .spotifyLightGray)
                            .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Previous
                    Button(action: { playerViewModel.playPrevious(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Play/Pause
                    Button(action: { playerViewModel.play(song: currentSong) }) {
                        Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Next
                    Button(action: { playerViewModel.playNext(currentSong: currentSong, allSongs: songs) }) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Repeat
                    Button(action: { playerViewModel.toggleRepeat() }) {
                        Image(systemName: playerViewModel.repeatMode == .repeatOne ? "repeat.1" : "repeat")
                            .font(.title3)
                            .foregroundColor(playerViewModel.repeatMode != .off ? .spotifyGreen : .spotifyLightGray)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .onAppear { sliderValue = playerViewModel.playbackTime }
        .onChange(of: playerViewModel.playbackTime) { _, newValue in
            if !isEditingSlider {
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
