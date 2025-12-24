
import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Barra de búsqueda
                    SearchBar(text: $searchViewModel.searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Filtros
                    FilterPicker(selectedFilter: $searchViewModel.selectedFilter)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // Resultados
                    if searchViewModel.searchText.isEmpty {
                        EmptySearchView()
                    } else if searchViewModel.filteredSongs.isEmpty {
                        NoResultsView()
                    } else {
                        SearchResultsList(
                            songs: searchViewModel.filteredSongs,
                            playerViewModel: playerViewModel
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Buscar")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            searchViewModel.updateSongs(songs)
        }
        .onChange(of: songs) {
            searchViewModel.updateSongs(songs)
        }
    }
}

#Preview {
    PreviewWrapper(
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { SearchView() }
}
