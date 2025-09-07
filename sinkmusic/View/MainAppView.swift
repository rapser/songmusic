
import SwiftUI
import SwiftData

struct MainAppView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        ContentView()
            .environmentObject(viewModel)
    }
}

