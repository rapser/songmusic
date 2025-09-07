
import SwiftUI

struct SearchView: View {
    
    @EnvironmentObject var playerViewModel: PlayerViewModel

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)
            Text("Search View")
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SearchView()
}
