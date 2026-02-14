//
//  BackgroundSessionCompletionService.swift
//  sinkmusic
//
//  Implementación del contrato de iOS para sesiones de descarga en segundo plano.
//  Sin singleton: se inyecta vía DIContainer en AppDelegate y MegaDownloadSession.
//

import Foundation

@MainActor
final class BackgroundSessionCompletionService: BackgroundSessionCompletionServiceProtocol {

    private var handler: (() -> Void)?

    func setCompletionHandler(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func completeBackgroundSession() {
        let h = handler
        handler = nil
        h?()
    }
}
