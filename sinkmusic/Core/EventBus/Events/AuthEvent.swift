//
//  AuthEvent.swift
//  sinkmusic
//
//  Created by Claude Code
//  Core Layer - Event Bus Events
//

import Foundation

/// Eventos de autenticación
/// Emitidos por AuthRepositoryImpl (Features/Auth), consumidos por AuthViewModel
enum AuthEvent: Sendable, Equatable {
    /// Usuario inició sesión exitosamente
    case signedIn(userID: String, email: String?, name: String?)

    /// Usuario cerró sesión
    case signedOut

    /// Verificación de autenticación completada
    case checkCompleted(isAuthenticated: Bool)
}

/// Estado actual de autenticación (observable)
enum AuthState: Sendable, Equatable {
    /// Estado desconocido (inicial)
    case unknown

    /// Verificando estado de autenticación
    case checking

    /// Usuario autenticado
    case authenticated(userID: String)

    /// Usuario no autenticado
    case unauthenticated
}
