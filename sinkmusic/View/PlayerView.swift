import SwiftUI
import SwiftData

struct PlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel
    var songs: [Song]
    var currentSong: Song
    
    @Environment(\.presentationMode) var presentationMode
    @State private var sliderValue: Double = 0
    @State private var isEditingSlider = false

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.gray)
                }
            }.padding()

            Image(systemName: "music.note")
                .font(.system(size: 200)).padding()
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack {
                Text(currentSong.title).font(.largeTitle).fontWeight(.bold)
                Text(currentSong.artist).font(.title2).foregroundColor(.secondary)
            }

            VStack {
                Slider(value: $sliderValue, in: 0...(viewModel.songDuration > 0 ? viewModel.songDuration : 1)) { editing in
                    isEditingSlider = editing
                    if !editing {
                        viewModel.seek(to: sliderValue)
                    }
                }
                HStack {
                    Text(formatTime(viewModel.playbackTime))
                    Spacer()
                    Text(formatTime(viewModel.songDuration))
                }.font(.caption).foregroundColor(.secondary)
            }.padding(.horizontal)

            HStack(spacing: 40) {
                Button(action: { viewModel.playPrevious(currentSong: currentSong, allSongs: songs) }) {
                    Image(systemName: "backward.fill").font(.largeTitle)
                }
                Button(action: { viewModel.play(song: currentSong) }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 60))
                }
                Button(action: { viewModel.stop() }) {
                    Image(systemName: "stop.fill").font(.largeTitle)
                }
                Button(action: { viewModel.playNext(currentSong: currentSong, allSongs: songs) }) {
                    Image(systemName: "forward.fill").font(.largeTitle)
                }
            }.foregroundColor(.primary)
            
            Spacer()
        }
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

// MARK: - Datos de prueba
extension Song {
    static let sampleSongs: [Song] = [
        Song(title: "Primera Canción", artist: "Artista A", fileID: "file1", isDownloaded: true),
        Song(title: "Segunda Canción", artist: "Artista B", fileID: "file2", isDownloaded: false),
        Song(title: "Tercera Canción", artist: "Artista C", fileID: "file3", isDownloaded: false)
    ]
}

extension MainViewModel {
    static func preview() -> MainViewModel {
        let vm = MainViewModel()
        vm.currentlyPlayingID = Song.sampleSongs[0].id
        vm.isPlaying = true
        vm.songDuration = 240
        vm.playbackTime = 42
        return vm
    }
}

#Preview {
    PlayerView(songs: Song.sampleSongs, currentSong: Song.sampleSongs[0])
        .environmentObject(MainViewModel.preview())
}

