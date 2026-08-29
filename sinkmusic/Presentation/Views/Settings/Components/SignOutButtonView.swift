//
//  SignOutButtonView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Sign Out Button (Reusable Component)

/// Texto rojo centrado, como "Cerrar sesión" en Ajustes de Apple/Tidal —
/// sin caja ni icono, al fondo de su propia sección.
struct SignOutButtonView: View {
    let onSignOut: () -> Void

    var body: some View {
        Button(action: onSignOut) {
            Text("Cerrar sesión")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
