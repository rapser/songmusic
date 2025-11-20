import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel

    @State private var selectedSegment = 0

    var filteredSongs: [Song] {
        switch selectedSegment {
        case 0: // Descargadas
            return songs.filter { $0.isDownloaded }
        case 1: // Pendientes
            return songs.filter { !$0.isDownloaded }
        default:
            return songs
        }
    }

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

            VStack {
                Text("Taki Music")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Picker("Filtro", selection: $selectedSegment) {
                    Text("Descargadas").tag(0)
                    Text("Pendientes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onAppear {
                    UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.spotifyGreen)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.spotifyLightGray)], for: .normal)
                    UISegmentedControl.appearance().backgroundColor = UIColor(Color.spotifyGray)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredSongs) { song in
                            SongRow(song: song)
                                .onTapGesture {
                                    if song.isDownloaded {
                                        playerViewModel.play(song: song)
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 80) // Espacio para el mini player
                }
                .padding(.horizontal, 16)
                
            }
        }
        .onAppear {
            viewModel.syncLibraryWithCatalog(modelContext: modelContext)
        }
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        songListVM: PreviewViewModels.songListVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { ContentView() }
}
