import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel

    @State private var lastOffset: CGFloat = 0
    @State private var scrollDirection: ScrollDirection = .up

    enum ScrollDirection {
        case up, down, none
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

                ScrollView() {
                    VStack(spacing: 10) {
                        ForEach(songs) { song in
                            SongRow(song: song)
                                .onTapGesture {
                                    playerViewModel.play(song: song)
                                }
                        }
                    }

                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                    }
                    .frame(height: 0)
                    
                }
                .padding(.horizontal, 16)
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newOffset in
                    let threshold: CGFloat = 5.0
                    
                    if abs(newOffset - lastOffset) > threshold {
                        if newOffset > lastOffset {
                            // Scroll hacia ABAJO - usuario se mueve HACIA ABAJO en el contenido
                            scrollDirection = .up
                            viewModel.isScrolling = false    // ✅ OCULTAR miniplayer
                            print("⬇️ Scroll DOWN - Ocultar miniplayer")
                        } else if newOffset < lastOffset {
                            // Scroll hacia ARRIBA - usuario se mueve HACIA ARRIBA en el contenido
                            scrollDirection = .down
                            viewModel.isScrolling = true   // ✅ MOSTRAR miniplayer
                            print("⬆️ Scroll UP - Mostrar miniplayer")
                        }
                    }
                    
                    lastOffset = newOffset
                }
                
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
