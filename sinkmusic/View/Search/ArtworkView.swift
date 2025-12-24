//
//  ArtworkView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct ArtworkView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.appGray)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.textGray)
                    )
            }
        }
    }
}
