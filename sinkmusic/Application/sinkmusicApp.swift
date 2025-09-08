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
        }
        .modelContainer(for: Song.self)
    }
}
