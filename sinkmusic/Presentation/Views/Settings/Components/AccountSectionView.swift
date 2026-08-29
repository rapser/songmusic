//
//  AccountSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Account Section (Reusable Component)

struct AccountSectionView: View {
    let profile: UserProfileData

    var body: some View {
        Group {
            if let email = profile.email {
                SettingsRowView(
                    icon: "envelope.fill",
                    iconColor: .blue,
                    title: "Correo electrónico",
                    value: email
                )
            } else {
                EmailNotSharedRowView()
            }

            if let userID = profile.userID {
                SettingsRowView(
                    icon: "person.text.rectangle.fill",
                    iconColor: .gray,
                    title: "ID de usuario",
                    value: String(userID.prefix(12))
                )
            }

            SettingsRowView(
                icon: "apple.logo",
                iconColor: .appGray,
                title: "Cuenta Apple",
                value: "Conectada"
            )
        }
    }
}

// MARK: - Email Not Shared Row

private struct EmailNotSharedRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemName: "envelope.fill", color: .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Correo electrónico")
                    .foregroundColor(.white)

                Text("No compartido por Apple")
                    .font(.caption)
                    .foregroundColor(.textGray)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
