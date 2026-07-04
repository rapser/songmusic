//
//  BatchResult.swift
//  sinkmusic
//

import Foundation

/// Resultado de una operación batch (descarga múltiple, eliminación múltiple).
/// Permite reportar éxitos parciales sin abortar el resto de la operación.
struct BatchResult<ID> {
    let succeeded: [ID]
    let failed: [(id: ID, error: Error)]

    var hasFailures: Bool { !failed.isEmpty }
    var allSucceeded: Bool { failed.isEmpty }
    var successCount: Int { succeeded.count }
    var failureCount: Int { failed.count }
}
