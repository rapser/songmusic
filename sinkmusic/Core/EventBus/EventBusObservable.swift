//
//  EventBusObservable.swift
//  sinkmusic
//

import Foundation

/// Mixin que elimina el boilerplate de suscripción al EventBus.
///
/// Cualquier ViewModel que observe el EventBus conforma este protocolo
/// y obtiene `makeEventTask` como implementación por defecto.
///
/// ## Uso
/// Solo lo usan ViewModels que reaccionan a eventos verdaderamente globales
/// (`PlaybackEvent`, `DownloadEvent`). La reactividad local de listas usa
/// `ReadStoreProtocol.changes()` en su lugar, no este mixin.
/// ```swift
/// final class DownloadViewModel: EventBusObservable {
///     var eventBus: EventBusProtocol
///     private var downloadEventTask: Task<Void, Never>?
///
///     init(eventBus: EventBusProtocol) {
///         self.eventBus = eventBus
///         downloadEventTask = makeEventTask(stream: { $0.downloadEvents() },
///                                           handler: { [weak self] in await self?.handleDownloadEvent($0) })
///     }
///     deinit { downloadEventTask?.cancel() }
/// }
/// ```
@MainActor
protocol EventBusObservable: AnyObject {
    var eventBus: EventBusProtocol { get }
}

extension EventBusObservable {
    /// Crea un Task que observa un stream del EventBus y llama a `handler` por cada evento.
    /// El Task respeta la cancelación y usa `[weak self]` internamente para evitar ciclos.
    func makeEventTask<E: Sendable>(
        stream: @escaping @MainActor (EventBusProtocol) -> AsyncStream<E>,
        handler: @escaping @MainActor (E) async -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in stream(self.eventBus) {
                guard !Task.isCancelled else { break }
                await handler(event)
            }
        }
    }
}
