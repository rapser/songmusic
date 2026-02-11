
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
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(songID: UUID()),
        playlistVM: PreviewViewModels.playlistVM(),
        modelContainer: PreviewContainer.shared.container
    ) {
        NavigationStack {
            LibraryView()
        }
    }
}
