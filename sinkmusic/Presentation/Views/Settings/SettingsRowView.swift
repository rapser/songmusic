//
//  SettingsRowView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//

import SwiftUI

/// Fila compacta para la lista de Ajustes (layout propio, sin `List`).
struct SettingsRowView: View {
    let icon: String
    var iconColor: Color = .textGray
    let title: String
    var titleColor: Color = .white
    var value: String? = nil
    /// Muestra el chevron de navegación al final (para filas dentro de un `NavigationLink`).
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            SettingsIconBadge(systemName: icon, color: iconColor)

            Text(title)
                .foregroundColor(titleColor)

            Spacer(minLength: 8)

            if let value = value {
                Text(value)
                    .foregroundColor(.textGray)
                    .font(.footnote)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.textGray.opacity(0.6))
            }
        }
        .frame(minHeight: 46)
        .contentShape(Rectangle())
    }
}
