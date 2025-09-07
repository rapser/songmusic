
import SwiftUI

struct LibraryView: View {
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
