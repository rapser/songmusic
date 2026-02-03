//
//  CarPlayService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

/// Servicio para manejar la integración con CarPlay
/// CarPlay ahora se maneja completamente a través de CarPlaySceneDelegate
/// y MPRemoteCommandCenter (configurado en AudioPlayerService)
///
/// El Now Playing Info y Remote Command Center están configurados en AudioPlayerService,
/// por lo que CarPlay los usa automáticamente sin necesidad de suscripciones adicionales.
///
/// SOLID: Init público para permitir DI desde DIContainer
@MainActor
final class CarPlayService: CarPlayServiceProtocol {

    // CRÍTICO: weak para evitar memory leak
    // Si mantiene referencia fuerte al ViewModel, nunca se libera
    private weak var playerViewModel: PlayerViewModel?

    /// Init público para permitir inyección de dependencias
    init() {}

    func configure(with playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        // No necesitamos suscripciones ya que CarPlay usa directamente
        // MPRemoteCommandCenter y MPNowPlayingInfoCenter de AudioPlayerService
    }
}
