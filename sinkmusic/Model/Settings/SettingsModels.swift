//
//  SettingsModels.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import Foundation

// MARK: - Settings Section Models

/// Representa una sección en la configuración
struct SettingsSection: Identifiable {
    let id: UUID = UUID()
    let title: String
    let items: [SettingsItem]
}

/// Representa un item individual en una sección
enum SettingsItem: Identifiable {
    case row(SettingsRowData)
    case userProfile(UserProfileData)
    case downloadButton(DownloadButtonData)
    case driveConfig(DriveConfigData)
    case deleteButton(DeleteButtonData)
    case signOutButton

    var id: String {
        switch self {
        case .row(let data):
            return data.id
        case .userProfile:
            return "user_profile"
        case .downloadButton:
            return "download_button"
        case .driveConfig:
            return "drive_config"
        case .deleteButton:
            return "delete_button"
        case .signOutButton:
            return "sign_out_button"
        }
    }
}

/// Datos para una fila de configuración estándar
struct SettingsRowData: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String?
    let showChevron: Bool
    let action: (@Sendable () -> Void)?

    init(
        id: String? = nil,
        icon: String,
        title: String,
        value: String? = nil,
        showChevron: Bool = true,
        action: (@Sendable () -> Void)? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.icon = icon
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self.action = action
    }

    static func == (lhs: SettingsRowData, rhs: SettingsRowData) -> Bool {
        lhs.id == rhs.id
    }
}

/// Datos para el perfil de usuario
struct UserProfileData: Sendable {
    let fullName: String?
    let email: String?
    let userID: String?
    let isAppleAccount: Bool
}

/// Datos para el botón de descarga
struct DownloadButtonData: Sendable {
    let pendingCount: Int
}

/// Datos para la configuración de Google Drive
struct DriveConfigData: Sendable {
    let isConfigured: Bool
}

/// Datos para el botón de eliminar descargas
struct DeleteButtonData: Sendable {
    let downloadedCount: Int
    let totalStorage: String
    let isEnabled: Bool
}

// MARK: - Settings State

/// Estado de la configuración
struct SettingsState {
    var pendingSongsCount: Int = 0
    var downloadedSongsCount: Int = 0
    var totalStorageUsed: String = "0 KB"
    var isGoogleDriveConfigured: Bool = false
    var userProfile: UserProfileData?
}
