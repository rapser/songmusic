//
//  EmptyAvailableSongsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//


import SwiftUI
import SwiftData

struct EmptyAvailableSongsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            VStack(spacing: 8) {
                Text("No hay canciones disponibles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Todas tus canciones ya están en otras playlists.\nElimina canciones de otras playlists para volver a agregarlas aquí.")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}