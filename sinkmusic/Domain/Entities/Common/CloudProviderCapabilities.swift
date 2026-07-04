//
//  CloudProviderCapabilities.swift
//  sinkmusic
//

import Foundation

/// Capacidades del proveedor de almacenamiento actualmente seleccionado.
/// Permite a ViewModels comportarse de forma adaptativa sin acoplarse
/// al enum `CloudStorageProvider`.
struct CloudProviderCapabilities {
    /// Nombre legible para mostrar en la UI
    let displayName: String
    /// El proveedor limita la cuota diaria de descargas
    let supportsQuotaTracking: Bool
    /// Mensaje que se muestra cuando se excede la cuota
    let quotaAlertMessage: String
    /// Número máximo de descargas concurrentes permitidas
    let maxConcurrentDownloads: Int
}
