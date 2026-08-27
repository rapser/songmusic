//
//  SectionHeaderView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Header de sección para `List` (estilo Ajustes de Spotify/Tidal: caption gris en mayúsculas).
/// Sin padding horizontal propio — `List` ya aplica los márgenes que alinean con las filas.
struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.textGray)
    }
}
