//
//  SettingsHeaderView.swift
//  sinkmusic
//
//  Header de la vista de configuración
//

import SwiftUI

struct SettingsHeaderView: View {
    var body: some View {
        Text("Configuración")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }
}
