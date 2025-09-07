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
    // Creamos el MainViewModel aquí, en el nivel más alto de la app
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(viewModel) // Inyectamos el ViewModel en el entorno
        }
        .modelContainer(for: Song.self) // Configuramos el contenedor de SwiftData
    }
}
