//
//  InstructionsCard.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct InstructionsCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.appPurple)

                    Text("¿Cómo obtener estas credenciales?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.textGray)
                        .font(.caption)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "Ve a Google Cloud Console")
                    InstructionStep(number: 2, text: "Crea un proyecto y habilita la API de Google Drive")
                    InstructionStep(number: 3, text: "Genera una API Key en 'Credenciales'")
                    InstructionStep(number: 4, text: "El Folder ID está en la URL de tu carpeta compartida de Drive")

                    Text("Ejemplo de URL:")
                        .font(.caption)
                        .foregroundColor(.textGray)
                        .padding(.top, 4)

                    Text("drive.google.com/drive/folders/[FOLDER_ID]")
                        .font(.caption)
                        .foregroundColor(.appPurple)
                        .padding(8)
                        .background(Color.appGray.opacity(0.5))
                        .cornerRadius(4)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.appGray)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}