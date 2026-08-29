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
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
