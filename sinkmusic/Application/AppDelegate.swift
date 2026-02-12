//
//  AppDelegate.swift
//  sinkmusic
//
//  Recibe el completion handler de iOS para la sesión de descargas en segundo plano
//  y lo guarda en el servicio inyectado (DIContainer) para que MegaDownloadSession lo invoque.
//

import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DIContainer.shared.backgroundSessionCompletionService.setCompletionHandler(completionHandler)
    }
}
