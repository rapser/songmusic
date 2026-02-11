//
//  AuthStrategyFactory.swift
//  sinkmusic
//
//  Features/Auth - Factory para crear estrategias según ambiente
//

import Foundation

/// Factory que crea la estrategia correcta según el proveedor y ambiente
@MainActor
enum AuthStrategyFactory {

    // MARK: - Provider

    /// Proveedor de autenticación disponible
    enum Provider: String, Sendable {
        case apple      // Sign In with Apple (default)
        case firebase   // Google via Firebase (futuro)
        case supabase   // Supabase Auth (futuro)
        case restAPI    // Custom REST API (futuro)
    }

    // MARK: - Factory Method

    /// Crear estrategia para el proveedor y ambiente actual
    /// - Parameters:
    ///   - provider: Proveedor de autenticación
    ///   - environment: Ambiente (default: actual)
    /// - Returns: Estrategia configurada
    static func makeStrategy(
        for provider: Provider,
        environment: AppEnvironment = .current
    ) -> AuthStrategy {
        switch provider {
        case .apple:
            // Apple no requiere configuración de ambiente
            // El sandbox/production se detecta automáticamente
            print("🔐 Auth Strategy: Apple Sign In (\(environment.displayName))")
            return AppleAuthStrategy()

        case .firebase:
            let config = FirebaseAuthConfig.forCurrentEnvironment()
            print("🔐 Auth Strategy: Firebase (\(config.plistName))")
            return makeFirebaseStrategy(config: config)

        case .supabase:
            let config = SupabaseAuthConfig.forCurrentEnvironment()
            print("🔐 Auth Strategy: Supabase (\(config.url.host ?? ""))")
            return makeSupabaseStrategy(config: config)

        case .restAPI:
            let config = RESTAPIAuthConfig.forCurrentEnvironment()
            print("🔐 Auth Strategy: REST API (\(config.baseURL.host ?? ""))")
            return makeRESTAPIStrategy(config: config)
        }
    }

    // MARK: - Private Factories

    private static func makeFirebaseStrategy(config: FirebaseAuthConfig) -> AuthStrategy {
        // TODO: Implementar cuando se agregue Firebase
        // FirebaseApp.configure(options: FirebaseOptions(contentsOfFile: config.plistName))
        // return FirebaseGoogleAuthStrategy()

        // Fallback a Apple
        print("⚠️ Firebase strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }

    private static func makeSupabaseStrategy(config: SupabaseAuthConfig) -> AuthStrategy {
        // TODO: Implementar cuando se agregue Supabase
        // return SupabaseAuthStrategy(url: config.url, key: config.anonKey)

        // Fallback a Apple
        print("⚠️ Supabase strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }

    private static func makeRESTAPIStrategy(config: RESTAPIAuthConfig) -> AuthStrategy {
        // TODO: Implementar cuando se agregue REST API
        // return RESTAPIAuthStrategy(baseURL: config.fullBaseURL, keychain: ...)

        // Fallback a Apple
        print("⚠️ REST API strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }
}
