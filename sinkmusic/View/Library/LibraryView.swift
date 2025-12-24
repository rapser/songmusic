
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            PlaylistListView(modelContext: modelContext)
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
