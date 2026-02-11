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
        VStack(spacing: 0) {
            SettingsRowView(
                icon: "info.circle.fill",
                title: "Versión",
                value: appVersion
            )

            SettingsRowView(
                icon: "doc.text.fill",
                title: "Términos y condiciones"
            )

            SettingsRowView(
                icon: "hand.raised.fill",
                title: "Política de privacidad"
            )
        }
    }
}
