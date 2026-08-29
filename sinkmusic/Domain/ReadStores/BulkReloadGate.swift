//
//  BulkReloadGate.swift
//  sinkmusic
//

import Foundation

/// Un read-side cuya reactividad se puede pausar durante una operación masiva.
///
/// Lo implementan los `ReadStore` concretos (reenvían a su `ModelContextChangeObserver`).
/// Los mocks lo obtienen gratis con la implementación por defecto (no-op).
@MainActor
protocol ReactiveReloadControllable: AnyObject {
    /// Pausa (`true`) o reanuda (`false`) las emisiones de `changes()`. Mientras está pausado,
    /// los cambios se colapsan en una única señal que se emite al reanudar.
    func setReactiveReloads(suspended: Bool)
}

extension ReactiveReloadControllable {
    func setReactiveReloads(suspended: Bool) {}
}

/// Pausa/reanuda la reactividad de **todas** las listas a la vez. Se usa para que
/// "Descargar todo" no dispare una recarga completa de Home/Library/Playlist/Search por
/// cada canción (coste O(nº canciones) × N canciones); en su lugar se recarga una sola vez
/// al terminar el lote.
@MainActor
protocol BulkReloadGate: AnyObject {
    func suspend()
    func resume()
}
