//
//  CarPlayServiceProtocol.swift
//  sinkmusic
//
//  Created by Claude Code - Clean Architecture
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de CarPlay
/// Permite mockear CarPlayService para testing
@MainActor
protocol CarPlayServiceProtocol: Sendable {

    // MARK: - Configuration

    /// Configura el servicio de CarPlay con el PlayerViewModel
    /// - Parameter playerViewModel: ViewModel del reproductor
    func configure(with playerViewModel: PlayerViewModel)
}
