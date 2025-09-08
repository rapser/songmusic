
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)
            Text("Búsqueda")
                .foregroundColor(.white)
                .font(.title)
        }
    }
}

#Preview {
    SearchView()
}
