//
//  AuthEnvironment.swift
//  sinkmusic
//
//  Features/Auth - Configuración de ambientes
//  Manejo de QA, Staging, Production
//

import Foundation

// MARK: - App Environment

/// Ambiente de ejecución de la app
enum AppEnvironment: String, Sendable {
    case development  // Local / Debug builds
    case qa           // Testing interno
    case staging      // Pre-producción
    case production   // App Store

    /// Detectar ambiente automáticamente desde build configuration
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #elseif QA
        return .qa
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var displayName: String {
        switch self {
        case .development: return "Development"
        case .qa: return "QA"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }
}

// MARK: - Auth Environment Config Protocol

/// Protocolo para configuración de ambientes de autenticación
protocol AuthEnvironmentConfig: Sendable {
    var environment: AppEnvironment { get }
}

// MARK: - Firebase Config (Futuro)

/// Configuración de Firebase por ambiente
struct FirebaseAuthConfig: AuthEnvironmentConfig, Sendable {
    let environment: AppEnvironment
    let plistName: String

    static func forCurrentEnvironment() -> FirebaseAuthConfig {
        switch AppEnvironment.current {
        case .development, .qa:
            return FirebaseAuthConfig(
                environment: .qa,
                plistName: "GoogleService-Info-QA"
            )
        case .staging:
            return FirebaseAuthConfig(
                environment: .staging,
                plistName: "GoogleService-Info-Staging"
            )
        case .production:
            return FirebaseAuthConfig(
                environment: .production,
                plistName: "GoogleService-Info"
            )
        }
    }
}

// MARK: - Supabase Config (Futuro)

/// Configuración de Supabase por ambiente
struct SupabaseAuthConfig: AuthEnvironmentConfig, Sendable {
    let environment: AppEnvironment
    let url: URL
    let anonKey: String

    static func forCurrentEnvironment() -> SupabaseAuthConfig {
        switch AppEnvironment.current {
        case .development, .qa:
            return SupabaseAuthConfig(
                environment: .qa,
                url: URL(string: "https://qa-project.supabase.co")!,
                anonKey: "eyJqa..." // Reemplazar con key real
            )
        case .staging:
            return SupabaseAuthConfig(
                environment: .staging,
                url: URL(string: "https://staging-project.supabase.co")!,
                anonKey: "eyJzdGFn..." // Reemplazar con key real
            )
        case .production:
            return SupabaseAuthConfig(
                environment: .production,
                url: URL(string: "https://prod-project.supabase.co")!,
                anonKey: "eyJwcm9k..." // Reemplazar con key real
            )
        }
    }
}

// MARK: - REST API Config (Futuro)

/// Configuración de REST API por ambiente
struct RESTAPIAuthConfig: AuthEnvironmentConfig, Sendable {
    let environment: AppEnvironment
    let baseURL: URL
    let apiVersion: String

    static func forCurrentEnvironment() -> RESTAPIAuthConfig {
        switch AppEnvironment.current {
        case .development:
            return RESTAPIAuthConfig(
                environment: .development,
                baseURL: URL(string: "http://localhost:8080")!,
                apiVersion: "v1"
            )
        case .qa:
            return RESTAPIAuthConfig(
                environment: .qa,
                baseURL: URL(string: "https://api-qa.example.com")!,
                apiVersion: "v1"
            )
        case .staging:
            return RESTAPIAuthConfig(
                environment: .staging,
                baseURL: URL(string: "https://api-staging.example.com")!,
                apiVersion: "v1"
            )
        case .production:
            return RESTAPIAuthConfig(
                environment: .production,
                baseURL: URL(string: "https://api.example.com")!,
                apiVersion: "v1"
            )
        }
    }

    var fullBaseURL: URL {
        baseURL.appendingPathComponent(apiVersion)
    }
}
