
import SwiftUI

struct LibraryView: View {
    
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)
            Text("Library View")
                .foregroundColor(.white)
        }
    }
}

#Preview {
    LibraryView()
}
