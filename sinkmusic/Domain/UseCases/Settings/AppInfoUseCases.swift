//
//  AppInfoUseCases.swift
//  sinkmusic
//
//  Domain Layer - UseCase
//

import Foundation

/// Versión y nombre de la app, para la sección "Acerca de".
///
/// No tiene dependencias: lee el `Bundle`, que se inyecta para poder probarlo con uno de
/// prueba. Estaba en `SettingsUseCases`, donde arrastraba cuatro repositorios que no usa.
@MainActor
final class AppInfoUseCases: Sendable {

    private static let displayName = "SinkMusic"

    func getAppInfo(bundle: Bundle = .main) -> AppInfo {
        AppInfo(
            version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            build: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            displayName: Self.displayName
        )
    }
}
