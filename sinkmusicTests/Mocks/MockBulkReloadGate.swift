//
//  MockBulkReloadGate.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

/// Espía de la puerta de recargas masivas: cuenta las pausas y reanudaciones y deja ver si
/// quedó abierta al terminar la operación.
@MainActor
final class MockBulkReloadGate: BulkReloadGate {

    private(set) var suspendCallCount = 0
    private(set) var resumeCallCount = 0

    /// `true` si hay más pausas que reanudaciones, es decir, si la reactividad quedó
    /// colgada. Debe ser `false` después de cualquier operación, incluso si falló.
    var isSuspended: Bool { suspendCallCount > resumeCallCount }

    func suspend() { suspendCallCount += 1 }

    func resume() { resumeCallCount += 1 }
}
