//
//  MiniPlayerArtwork.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Artwork del miniplayer (42×42).
///
/// Recibe la imagen ya resuelta: la carátula de la canción en curso si está decodificada, y
/// el thumbnail mientras llega. El thumbnail son 32 px (se genera para la Live Activity) y
/// esta vista son 42 pt, o sea 126 px en pantalla @3x — pintarlo solo a él lo ampliaba
/// cuatro veces y se veía borroso.
struct MiniPlayerArtwork: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
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
