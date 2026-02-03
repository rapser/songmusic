//
//  AuthUserDTO.swift
//  sinkmusic
//
//  Features/Auth - Data Layer DTO
//  Clean Architecture: Data Transfer Object para persistencia
//

import Foundation

/// DTO para datos de usuario en la capa de datos
/// Representa la estructura de datos como se almacena en UserDefaults
///
/// ## Clean Architecture
/// - **Data Layer**: Estructura de persistencia
/// - **Mapeo**: AuthMapper convierte DTO ↔ Entity
///
/// ## Uso
/// ```swift
/// // Guardar
/// let dto = AuthUserDTO(id: "apple_id", email: "user@email.com", fullName: "John Doe")
/// localDataSource.save(dto)
///
/// // Cargar
/// let dto = localDataSource.load()
/// let entity = AuthMapper.toEntity(from: dto)
/// ```
struct AuthUserDTO: Codable, Sendable, Equatable {
    /// ID único del usuario (proporcionado por Apple)
    let id: String

    /// Email del usuario (opcional, Apple puede ocultarlo)
    let email: String?

    /// Nombre completo del usuario
    let fullName: String?

    /// Fecha de creación del registro
    let createdAt: Date

    /// Fecha de última actualización
    let updatedAt: Date

    // MARK: - Initialization

    init(
        id: String,
        email: String?,
        fullName: String?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - UserDefaults Keys

extension AuthUserDTO {
    /// Claves para almacenamiento en UserDefaults
    enum StorageKeys {
        static let userDTO = "auth_user_dto"
        static let legacyUserID = "apple_user_id"
        static let legacyEmail = "apple_user_email"
        static let legacyFullName = "apple_user_fullName"
    }
}
