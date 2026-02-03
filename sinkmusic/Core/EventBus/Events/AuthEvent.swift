//
//  AuthEvent.swift
//  sinkmusic
//
//  Created by Claude Code
//  Core Layer - Event Bus Events
//

import Foundation

/// Eventos de autenticación
/// Emitidos por AuthFacade (Features/Auth), consumidos por otros módulos
enum AuthEvent: Sendable, Equatable {
    /// Usuario inició sesión exitosamente
    case signedIn(userID: String, email: String?, name: String?)

    /// Usuario cerró sesión
    case signedOut

    /// Verificación de autenticación completada
    case checkCompleted(isAuthenticated: Bool)
}

// NOTA: AuthState ahora está definido en Features/Auth/AuthState.swift
