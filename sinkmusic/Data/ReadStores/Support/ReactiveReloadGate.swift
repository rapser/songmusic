//
//  ReactiveReloadGate.swift
//  sinkmusic
//

import Foundation

/// Implementación de `BulkReloadGate` sobre los `ReadStore` concretos.
/// Reentrante: si se llama `suspend()` dos veces, hacen falta dos `resume()` para reanudar.
@MainActor
final class ReactiveReloadGate: BulkReloadGate {

    private let controllables: [any ReactiveReloadControllable]
    private var depth = 0

    init(_ controllables: [any ReactiveReloadControllable]) {
        self.controllables = controllables
    }

    func suspend() {
        depth += 1
        if depth == 1 {
            controllables.forEach { $0.setReactiveReloads(suspended: true) }
        }
    }

    func resume() {
        guard depth > 0 else { return }
        depth -= 1
        if depth == 0 {
            controllables.forEach { $0.setReactiveReloads(suspended: false) }
        }
    }
}
