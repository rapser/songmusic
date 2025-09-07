
import SwiftUI

struct SearchView: View {
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
