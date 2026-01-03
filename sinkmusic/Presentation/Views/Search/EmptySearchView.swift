//
//  EmptySearchView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            Text("Encuentra tu música")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Busca canciones, artistas o álbumes")
                .font(.subheadline)
                .foregroundColor(.textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
