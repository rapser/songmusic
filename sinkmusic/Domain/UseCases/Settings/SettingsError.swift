//
//  SettingsError.swift
//  sinkmusic
//
//  Domain Layer - Error
//

import Foundation

enum SettingsError: Error {
    case invalidCredentials
    case connectionFailed(Error)
    case saveFailed
}
