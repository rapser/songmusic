//
//  MiniPlayerArtwork.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Artwork del miniplayer (42x42) - Usa thumbnail optimizado para máximo rendimiento
struct MiniPlayerArtwork: View {
    let cachedThumbnail: UIImage?

    var body: some View {
        Group {
            if let image = cachedThumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                ZStack {
                    Color.appPurple
                        .frame(width: 42, height: 42)
                        .cornerRadius(4)

                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white)
                }
            }
        }
    }
}
