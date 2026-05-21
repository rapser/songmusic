//
//  EmptyAvailableSongsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//

import SwiftUI

struct EmptyAvailableSongsView: View {
    enum Reason {
        case noDownloads
        case allInPlaylists
    }

    var reason: Reason = .allInPlaylists

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: reason == .noDownloads ? "arrow.down.circle" : "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            VStack(spacing: 8) {
                Text(reason == .noDownloads ? "Sin canciones descargadas" : "No hay canciones disponibles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(reason == .noDownloads
                     ? "Descarga canciones desde la sección de búsqueda para poder agregarlas a tus playlists."
                     : "Todas tus canciones descargadas ya están en otras playlists."
                )
                .font(.system(size: 14))
                .foregroundColor(.textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
