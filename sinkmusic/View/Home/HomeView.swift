import SwiftUI

struct HomeView: View {

    var body: some View {
        
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("App Music")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Lista de playlists en 2 columnas
                
                Spacer()
                
            }
        }
    }
}

#Preview {
    HomeView()
}
