//
//  MenuButton.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//

import SwiftUI

/// Etiqueta visual de tres puntos (estilo Spotify). Se usa como label de Menu.
/// Área táctil ampliada (56pt) para que el toque abra el menú y no dispare el tap de la fila.
struct ThreeDotsLabel: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.textGray)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(minWidth: 56, minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Botón de menú de tres puntos que abre un confirmationDialog (legacy).
/// Preferir usar Menu { } label: { ThreeDotsLabel() } para estilo Spotify.
struct MenuButton: View {
    @Binding var showMenu: Bool

    var body: some View {
        Button(action: { showMenu = true }) {
            ThreeDotsLabel()
        }
        .buttonStyle(.plain)
        .padding(.trailing, -8)
    }
}
