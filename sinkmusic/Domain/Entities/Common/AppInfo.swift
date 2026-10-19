//
//  AppInfo.swift
//  sinkmusic
//
//  Domain Layer - Entity
//

import Foundation

struct AppInfo: Sendable {
    let version: String
    let build: String
    let displayName: String

    var fullVersion: String { "\(version) (\(build))" }
}
