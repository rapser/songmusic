//
//  MiniPlayerArtwork.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Artwork del miniplayer (42x42) - Solo usa imagen cacheada para máximo rendimiento
struct MiniPlayerArtwork: View {
    let cachedImage: UIImage?

    var body: some View {
        Group {
            if let image = cachedImage {
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
