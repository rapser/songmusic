//
//  SettingsIconBadge.swift
//  sinkmusic
//
//  Icono a color en cuadrado redondeado, estilo Ajustes de iOS / Tidal.
//

import SwiftUI

struct SettingsIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 28, height: 28)

            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
