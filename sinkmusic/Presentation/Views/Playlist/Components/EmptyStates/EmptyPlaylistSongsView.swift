//
//  EmptyPlaylistSongsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//

import SwiftUI

struct EmptyPlaylistSongsView: View{
    var onAddSongs: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.textGray)

            VStack(spacing: 4) {
                Text("No hay canciones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Agrega canciones a esta playlist")
                    .font(.system(size: 13))
                    .foregroundColor(.textGray)
            }
            
            Button(action: { onAddSongs?() }) {
                Text("Agregar canciones")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }
            .padding(.top, 10)

        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}