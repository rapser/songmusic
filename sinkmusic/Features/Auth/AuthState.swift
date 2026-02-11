//
//  AuthState.swift
//  sinkmusic
//
//  Features/Auth - Estados y modelo único
//  Facade + Strategy Pattern
//

import Foundation

// MARK: - Auth State

/// Estado de autenticación
enum AuthState: Equatable, Sendable {
    case unknown
    case checking
    case authenticated(AuthUser)
    case unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var user: AuthUser? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

// MARK: - Auth User

/// Modelo único de usuario (persistencia + UI)
struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let email: String?
    let fullName: String?
    let provider: AuthProvider
    let createdAt: Date

    // MARK: - Computed para UI (reemplaza UIModel separado)

    var displayName: String {
        fullName ?? "Usuario"
    }

    var displayEmail: String {
        email ?? "Email privado"
    }

    var initials: String {
        guard let name = fullName, !name.isEmpty else { return "U" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Miembro desde \(formatter.string(from: createdAt))"
    }

    var hasEmail: Bool {
        email != nil && !email!.isEmpty
    }

    var hasName: Bool {
        fullName != nil && !fullName!.isEmpty
    }
}

// MARK: - Auth Provider

/// Proveedor de autenticación
enum AuthProvider: String, Codable, Sendable {
    case apple
    case google      // Firebase/Google Sign In (futuro)
    case supabase    // Supabase Auth (futuro)
    case restAPI     // Custom REST API (futuro)
}

// MARK: - Auth Error

/// Errores de autenticación
enum AuthError: Error, LocalizedError, Sendable {
    case configurationMissing
    case noRootViewController
    case missingToken
    case userNotFound
    case invalidResponse
    case credentialsRequired
    case tokenExpired
    case cancelled
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Configuración de autenticación no encontrada"
        case .noRootViewController:
            return "No se puede presentar la pantalla de login"
        case .missingToken:
            return "Token de autenticación no recibido"
        case .userNotFound:
            return "Usuario no encontrado"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .credentialsRequired:
            return "Se requieren credenciales (email/password)"
        case .tokenExpired:
            return "La sesión ha expirado"
        case .cancelled:
            return "Autenticación cancelada"
        case .networkError(let message):
            return "Error de red: \(message)"
        }
    }
}
