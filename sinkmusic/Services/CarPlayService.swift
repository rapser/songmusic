//
//  CarPlayService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import Combine

/// Servicio para manejar la integración con CarPlay
/// CarPlay ahora se maneja completamente a través de CarPlaySceneDelegate
/// y MPRemoteCommandCenter (configurado en AudioPlayerService)
@MainActor
class CarPlayService {
    static let shared = CarPlayService()

    private var playerViewModel: PlayerViewModel?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Inicialización privada para singleton
    }

    func configure(with playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let playerViewModel = playerViewModel else { return }

        // Suscribirse a cambios en el estado de reproducción
        // El Now Playing Info y Remote Command Center ya están configurados
        // en AudioPlayerService, por lo que CarPlay los usará automáticamente
        playerViewModel.$isPlaying
            .sink {_ in }
            .store(in: &cancellables)

        playerViewModel.$currentlyPlayingID
            .sink { _ in }
            .store(in: &cancellables)
    }
}
