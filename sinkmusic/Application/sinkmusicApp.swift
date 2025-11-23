//
//  sinkmusicApp.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI
import SwiftData

@main
struct sinkmusicApp: App {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var songListViewModel = SongListViewModel()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.playerViewModel)
                .environmentObject(songListViewModel)
                .onAppear {
                    // Configurar CarPlay cuando la app aparece
                    CarPlayService.shared.configure(with: viewModel.playerViewModel)
                }
        }
        .modelContainer(for: [Song.self, Playlist.self])
    }
}
