//
//  AuthMapper.swift
//  sinkmusic
//
//  Features/Auth - Data Layer Mapper
//  Clean Architecture: Mapeo entre las 3 capas
//

import Foundation
import AuthenticationServices

/// Mapper para convertir entre DTOs, Entities y UIModels de autenticación
///
/// ## Clean Architecture - Flujo de Datos
/// ```
/// Apple SDK                    Data Layer        Domain Layer      Presentation Layer
/// ───────────────────────────────────────────────────────────────────────────────────
/// AppleCredentialProtocol  →   AuthUserDTO   →   AuthUserEntity  →   AuthUserUIModel
///        ↓                         ↓                   ↓                    ↓
///   (Sign In)               (UserDefaults)        (Business)            (SwiftUI)
/// ```
///
/// ## Métodos de Conversión
/// - `toDTO`: Credential/Entity → DTO (para persistencia)
/// - `toEntity`: DTO/Credential → Entity (para lógica de negocio)
/// - `toUIModel`: Entity → UIModel (para presentación)
enum AuthMapper {

    // MARK: - Credential → Entity (Sign In Flow)

    /// Convierte credencial de Apple a AuthUserEntity
    /// - Parameters:
    ///   - credential: Credencial que conforma a AppleCredentialProtocol
    ///   - storedEmail: Email almacenado previamente (Apple solo lo envía la primera vez)
    ///   - storedName: Nombre almacenado previamente
    /// - Returns: AuthUserEntity
    static func toEntity(
        from credential: AppleCredentialProtocol,
        storedEmail: String?,
        storedName: String?
    ) -> AuthUserEntity {
        // Email: usar el nuevo si existe, o el almacenado
        let email = credential.email ?? storedEmail

        // Nombre: construir desde fullName o usar el almacenado
        let fullName: String?
        if let nameComponents = credential.fullName {
            let name = [nameComponents.givenName, nameComponents.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            fullName = name.isEmpty ? storedName : name
        } else {
            fullName = storedName
        }

        return AuthUserEntity(
            id: credential.user,
            email: email,
            fullName: fullName
        )
    }

    // MARK: - DTO ↔ Entity

    /// Convierte AuthUserDTO a AuthUserEntity
    /// - Parameter dto: DTO desde persistencia
    /// - Returns: AuthUserEntity para lógica de negocio
    static func toEntity(from dto: AuthUserDTO) -> AuthUserEntity {
        AuthUserEntity(
            id: dto.id,
            email: dto.email,
            fullName: dto.fullName,
            createdAt: dto.createdAt
        )
    }

    /// Convierte AuthUserEntity a AuthUserDTO
    /// - Parameter entity: Entity de dominio
    /// - Returns: AuthUserDTO para persistencia
    static func toDTO(from entity: AuthUserEntity) -> AuthUserDTO {
        AuthUserDTO(
            id: entity.id,
            email: entity.email,
            fullName: entity.fullName,
            createdAt: entity.createdAt,
            updatedAt: Date()
        )
    }

    /// Convierte datos primitivos a AuthUserEntity (legacy support)
    /// - Parameters:
    ///   - id: ID del usuario
    ///   - email: Email opcional
    ///   - fullName: Nombre opcional
    /// - Returns: AuthUserEntity
    static func toEntity(
        id: String,
        email: String?,
        fullName: String?
    ) -> AuthUserEntity {
        AuthUserEntity(
            id: id,
            email: email,
            fullName: fullName
        )
    }

    // MARK: - Entity → UIModel

    /// Convierte AuthUserEntity a AuthUserUIModel
    /// - Parameter entity: Entity de dominio
    /// - Returns: AuthUserUIModel para presentación
    static func toUIModel(from entity: AuthUserEntity) -> AuthUserUIModel {
        AuthUserUIModel(
            id: entity.id,
            email: entity.email,
            fullName: entity.fullName,
            createdAt: entity.createdAt
        )
    }

    /// Convierte AuthenticationState a AuthUserUIModel opcional
    /// - Parameter state: Estado de autenticación
    /// - Returns: UIModel si está autenticado, nil si no
    static func toUIModel(from state: AuthenticationState) -> AuthUserUIModel? {
        switch state {
        case .authenticated(let user):
            return toUIModel(from: user)
        case .unknown, .checking, .unauthenticated:
            return nil
        }
    }

    // MARK: - Entity → Event

    /// Convierte AuthUserEntity a AuthEvent para EventBus
    /// - Parameter user: Entity del usuario
    /// - Returns: AuthEvent.signedIn
    static func toAuthEvent(_ user: AuthUserEntity) -> AuthEvent {
        .signedIn(userID: user.id, email: user.email, name: user.fullName)
    }

    // MARK: - Credential → DTO (Direct)

    /// Convierte credencial de Apple directamente a DTO
    /// Útil cuando se quiere persistir inmediatamente sin pasar por Entity
    /// - Parameters:
    ///   - credential: Credencial de Apple
    ///   - storedEmail: Email almacenado previamente
    ///   - storedName: Nombre almacenado previamente
    /// - Returns: AuthUserDTO
    static func toDTO(
        from credential: AppleCredentialProtocol,
        storedEmail: String?,
        storedName: String?
    ) -> AuthUserDTO {
        let entity = toEntity(from: credential, storedEmail: storedEmail, storedName: storedName)
        return toDTO(from: entity)
    }
}
