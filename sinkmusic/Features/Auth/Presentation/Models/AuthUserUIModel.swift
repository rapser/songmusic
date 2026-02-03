//
//  AuthUserUIModel.swift
//  sinkmusic
//
//  Features/Auth - Presentation Layer UI Model
//  Clean Architecture: Modelo optimizado para la UI
//

import Foundation

/// Modelo de UI para mostrar información del usuario autenticado
///
/// ## Clean Architecture
/// - **Presentation Layer**: Datos formateados para la UI
/// - **Inmutable**: Struct para SwiftUI rendering eficiente
/// - **Mapeo**: AuthMapper convierte Entity → UIModel
///
/// ## Diferencias con AuthUserEntity
/// - Propiedades formateadas para display
/// - Valores por defecto para UI (no opcionales donde sea posible)
/// - Propiedades computadas para formateo
struct AuthUserUIModel: Sendable, Equatable, Identifiable {

    // MARK: - Properties

    /// ID único del usuario
    let id: String

    /// Email para mostrar (con fallback)
    let displayEmail: String

    /// Nombre para mostrar (con fallback)
    let displayName: String

    /// Iniciales para avatar
    let initials: String

    /// Indica si el email está disponible
    let hasEmail: Bool

    /// Indica si el nombre está disponible
    let hasName: Bool

    /// Fecha de registro formateada
    let memberSinceFormatted: String

    // MARK: - Initialization

    init(
        id: String,
        email: String?,
        fullName: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hasEmail = email != nil && !email!.isEmpty
        self.hasName = fullName != nil && !fullName!.isEmpty

        // Display email con fallback
        self.displayEmail = email ?? "Email privado"

        // Display name con fallback
        self.displayName = fullName ?? "Usuario"

        // Calcular iniciales
        self.initials = Self.calculateInitials(from: fullName)

        // Formatear fecha
        self.memberSinceFormatted = Self.formatMemberSince(createdAt)
    }

    // MARK: - Private Helpers

    private static func calculateInitials(from name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return "U"
        }

        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1).uppercased()
            let last = components[1].prefix(1).uppercased()
            return "\(first)\(last)"
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private static func formatMemberSince(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return "Miembro desde \(formatter.string(from: date))"
    }
}

// MARK: - Factory Methods

extension AuthUserUIModel {
    /// Crea un modelo de UI placeholder para estados de carga
    static var placeholder: AuthUserUIModel {
        AuthUserUIModel(
            id: "",
            email: nil,
            fullName: nil
        )
    }

    /// Crea un modelo de UI para usuario invitado
    static var guest: AuthUserUIModel {
        AuthUserUIModel(
            id: "guest",
            email: nil,
            fullName: "Invitado"
        )
    }
}
