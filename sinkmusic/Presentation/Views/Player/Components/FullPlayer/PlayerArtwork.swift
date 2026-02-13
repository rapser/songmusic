//
//  PlayerArtwork.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Artwork grande del player
struct PlayerArtwork: View {
    let artworkData: Data?
    let cachedImage: UIImage?
    var namespace: Namespace.ID

    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .drawingGroup() // Renderizado nítido al escalar imagen de alta resolución
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appPurple)
                        .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)

                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}
