//
//  SettingsHeaderView.swift
//  sinkmusic
//
//  Header de la vista de configuración
//

import SwiftUI

struct SettingsHeaderView: View {
    var body: some View {
        Text("Ajustes")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}
