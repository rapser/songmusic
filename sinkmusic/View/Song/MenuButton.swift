//
//  MenuButton.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Botón de menú de tres puntos
struct MenuButton: View {
    @Binding var showMenu: Bool

    var body: some View {
        Button(action: { showMenu = true }) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.textGray)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, -8)
    }
}
