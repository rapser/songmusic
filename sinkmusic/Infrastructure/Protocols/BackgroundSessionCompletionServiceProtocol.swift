//
//  BackgroundSessionCompletionServiceProtocol.swift
//  sinkmusic
//
//  Infrastructure - Protocol for background URLSession completion (iOS contract).
//  Permite inyección en AppDelegate y MegaDownloadSession sin singleton.
//

import Foundation

/// Servicio que almacena e invoca el completion handler que iOS entrega para sesiones
/// en segundo plano. Requerido para que las descargas sigan con la pantalla apagada.
@MainActor
protocol BackgroundSessionCompletionServiceProtocol: AnyObject {

    /// Guarda el handler que iOS pasa en `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    func setCompletionHandler(_ handler: @escaping () -> Void)

    /// Invoca el handler cuando la sesión de fondo termina de procesar eventos.
    /// Debe llamarse desde MainActor (p. ej. desde `urlSessionDidFinishEvents(forBackgroundURLSession:)`).
    func completeBackgroundSession()
}
