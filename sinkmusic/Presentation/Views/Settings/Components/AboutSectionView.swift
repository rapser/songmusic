//
//  AboutSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - About Section (Reusable Component)

struct AboutSectionView: View {
    let appVersion: String

    var body: some View {
        Group {
            SettingsRowView(
                icon: "info.circle.fill",
                iconColor: .gray,
                title: "Versión",
                value: appVersion
            )

            SettingsRowView(
                icon: "doc.text.fill",
                iconColor: .gray,
                title: "Términos y condiciones"
            )

            SettingsRowView(
                icon: "hand.raised.fill",
                iconColor: .gray,
                title: "Política de privacidad"
            )
        }
    }
}
