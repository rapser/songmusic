//
//  SettingsRowView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct SettingsRowView: View {
    let icon: String
    let title: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.textGray)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.white)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.textGray)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.textGray)
                .font(.caption)
        }
        .padding(16)
        .background(Color.appGray)
    }
}
