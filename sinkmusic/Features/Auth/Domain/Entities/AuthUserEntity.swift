//
//  AuthUserEntity.swift
//  sinkmusic
//
//  Features/Auth - Domain Layer Entity
//  Clean Architecture: Entidad pura del dominio
//

import Foundation

/// Entidad de usuario autenticado
/// Domain Layer - Sin dependencias externas
struct AuthUserEntity: Sendable, Equatable {
    let id: String
    let email: String?
    let fullName: String?
    let createdAt: Date

    init(id: String, email: String?, fullName: String?, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
    }
}

/// Estado de autenticación del dominio
enum AuthenticationState: Sendable, Equatable {
    case unknown
    case checking
    case authenticated(user: AuthUserEntity)
    case unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var user: AuthUserEntity? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}
