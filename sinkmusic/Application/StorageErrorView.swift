//
//  StorageErrorView.swift
//  sinkmusic
//
//  Pantalla mostrada cuando el `ModelContainer` de SwiftData no se pudo abrir
//  (p. ej. una migración fallida). Sustituye al `fatalError` que dejaba la app
//  en un crash-loop al arrancar, sin información para el usuario ni telemetría.
//

import SwiftUI

struct StorageErrorView: View {
    let details: String

    var body: some View {
        ZStack {
            Color.appDark.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundColor(.appPurple)

                Text("No se pudo abrir tu biblioteca")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("La base de datos local no se pudo cargar. Tus descargas no se han borrado. "
                     + "Reinicia la app; si el problema continúa, reinstálala o contacta con soporte.")
                    .font(.subheadline)
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                ScrollView {
                    Text(details)
                        .font(.caption2.monospaced())
                        .foregroundColor(.textGray.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 160)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 24)
            }
        }
    }
}
