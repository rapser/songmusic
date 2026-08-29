//
//  AuthStrategyFactory.swift
//  sinkmusic
//
//  Features/Auth - Factory para crear estrategias según ambiente
//

import Foundation
import os

/// Factory que crea la estrategia correcta según el proveedor y ambiente
@MainActor
enum AuthStrategyFactory {

    private static let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Auth")

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
            logger.info("Auth Strategy: Apple Sign In (\(environment.displayName))")
            return AppleAuthStrategy()

        case .firebase:
            let config = FirebaseAuthConfig.forCurrentEnvironment()
            logger.info("Auth Strategy: Firebase (\(config.plistName))")
            return makeFirebaseStrategy(config: config)

        case .supabase:
            let config = SupabaseAuthConfig.forCurrentEnvironment()
            logger.info("Auth Strategy: Supabase (\(config.url.host ?? ""))")
            return makeSupabaseStrategy(config: config)

        case .restAPI:
            let config = RESTAPIAuthConfig.forCurrentEnvironment()
            logger.info("Auth Strategy: REST API (\(config.baseURL.host ?? ""))")
            return makeRESTAPIStrategy(config: config)
        }
    }

    // MARK: - Private Factories

    private static func makeFirebaseStrategy(config: FirebaseAuthConfig) -> AuthStrategy {
        // NOTA (no implementado): estrategia Firebase prevista; hoy cae a Apple. Rastreado fuera del código.
        // FirebaseApp.configure(options: FirebaseOptions(contentsOfFile: config.plistName))
        // return FirebaseGoogleAuthStrategy()

        // Fallback a Apple
        logger.warning("Firebase strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }

    private static func makeSupabaseStrategy(config: SupabaseAuthConfig) -> AuthStrategy {
        // NOTA (no implementado): estrategia Supabase prevista; hoy cae a Apple. Rastreado fuera del código.
        // return SupabaseAuthStrategy(url: config.url, key: config.anonKey)

        // Fallback a Apple
        logger.warning("Supabase strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }

    private static func makeRESTAPIStrategy(config: RESTAPIAuthConfig) -> AuthStrategy {
        // NOTA (no implementado): estrategia REST API prevista; hoy cae a Apple. Rastreado fuera del código.
        // return RESTAPIAuthStrategy(baseURL: config.fullBaseURL, keychain: ...)

        // Fallback a Apple
        logger.warning("REST API strategy not implemented, using Apple fallback")
        return AppleAuthStrategy()
    }
}
