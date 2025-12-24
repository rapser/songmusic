//
//  EmptyPlaylistsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 21/12/25.
//


import SwiftUI
import SwiftData

struct EmptyPlaylistsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            VStack(spacing: 8) {
                Text("No tienes playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Crea tu primera playlist para empezar")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
            }

            Button(action: onCreate) {
                Text("Crear playlist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }
            .padding(.top, 10)

            Spacer()
        }
    }
}