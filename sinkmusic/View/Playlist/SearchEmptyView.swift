//
//  SearchEmptyView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//

import SwiftUI

struct SearchEmptyView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            VStack(spacing: 8) {
                Text("No se encontraron resultados")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("No hay canciones que coincidan con '\(searchText)'")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
