//
//  SignOutButtonView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Sign Out Button (Reusable Component)

struct SignOutButtonView: View {
    let onSignOut: () -> Void

    var body: some View {
        Button(action: onSignOut) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .foregroundColor(.white)
                    .frame(width: 24)

                Text("Cerrar sesión")
                    .foregroundColor(.white)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(16)
            .background(Color.red.opacity(0.7))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 100)
    }
}
