//
//  ReactiveReload.swift
//  sinkmusic
//
//  Core - utilidad de concurrencia
//

import Foundation

/// Bucle estándar de recarga reactiva de los ViewModels: consume un `AsyncStream<Void>`
/// de señales "algo cambió" (de un ReadStore) y ejecuta `onSignal` en cada una, hasta que
/// la `Task` devuelta se cancele.
///
/// Sustituye el `for await _ in readStore.changes() { guard !Task.isCancelled ... }`
/// que estaba copiado en `Home`/`Library`/`Search`/`PlaylistViewModel`. El ViewModel
/// sigue guardando la `Task` y cancelándola en `deinit`.
@MainActor
enum ReactiveReload {

    static func loop(
        _ stream: AsyncStream<Void>,
        onSignal: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        Task {
            for await _ in stream {
                guard !Task.isCancelled else { break }
                await onSignal()
            }
        }
    }
}
