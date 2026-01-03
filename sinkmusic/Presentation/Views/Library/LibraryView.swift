
import SwiftUI

struct LibraryView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel

    var body: some View {
        NavigationStack {
            PlaylistListView()
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .modelContainer(PreviewContainer.shared.container)
            .environmentObject(PreviewViewModels.playerVM(songID: UUID()))
    }
}
