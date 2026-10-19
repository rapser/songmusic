
import SwiftUI

struct SearchView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Barra de búsqueda
                    SearchBar(text: Binding(
                        get: { viewModel.searchQuery },
                        set: { newValue in
                            viewModel.searchQuery = newValue
                            Task {
                                await viewModel.search()
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Filtros
                    FilterPicker(selectedFilter: Binding(
                        get: {
                            // Mapear SortOption a SearchFilter (legacy)
                            convertToSearchFilter(viewModel.sortOption)
                        },
                        set: { newFilter in
                            let sortOption = convertToSortOption(newFilter)
                            Task {
                                await viewModel.changeSortOption(sortOption)
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Loading State
                    if viewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                    }
                    // Resultados
                    else if viewModel.searchQuery.isEmpty {
                        EmptySearchView()
                    } else if viewModel.searchResults.isEmpty {
                        NoResultsView()
                    } else {
                        SearchResultsList(
                            songs: viewModel.searchResults
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
        // Sin `.task`: aquí se volvían a cargar agregaciones y recomendaciones en **cada**
        // aparición de la pestaña. El ViewModel vive mientras vive la app (lo crea
        // `sinkmusicApp`), las carga una vez en su `init` y su bucle reactivo las mantiene
        // al día ante cualquier cambio de canciones.
    }

    // MARK: - Helpers para compatibilidad con FilterPicker legacy

    private func convertToSearchFilter(_ sortOption: SortOption) -> SearchFilter {
        switch sortOption {
        case .title: return .all
        case .artist: return .artist
        case .album: return .album
        case .playCount: return .notDownloaded
        case .duration: return .all
        case .recentlyPlayed: return .all
        }
    }

    private func convertToSortOption(_ filter: SearchFilter) -> SortOption {
        switch filter {
        case .all: return .title
        case .song: return .title
        case .artist: return .artist
        case .album: return .album
        case .downloaded: return .artist
        case .notDownloaded: return .playCount
        }
    }
}

#Preview {
    PreviewWrapper(
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { SearchView() }
}
