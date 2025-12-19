//
//  NoResultsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.textGray)

            Text("No se encontraron resultados")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Intenta buscar algo diferente")
                .font(.subheadline)
                .foregroundColor(.textGray)

            Spacer()
        }
    }
}
