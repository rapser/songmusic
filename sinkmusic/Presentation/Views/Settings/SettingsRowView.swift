//
//  SettingsRowView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//

import SwiftUI

/// Fila plana para listas de Ajustes (sin fondo propio ni chevron manual —
/// eso lo aporta `List`/`NavigationLink` de forma nativa cuando la fila navega).
struct SettingsRowView: View {
    let icon: String
    var iconColor: Color = .textGray
    let title: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemName: icon, color: iconColor)

            Text(title)
                .foregroundColor(.white)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.textGray)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
