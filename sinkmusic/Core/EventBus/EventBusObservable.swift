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
/// ```swift
/// final class LibraryViewModel: EventBusObservable {
///     var eventBus: EventBusProtocol
///     private var dataEventTask: Task<Void, Never>?
///
///     init(eventBus: EventBusProtocol) {
///         self.eventBus = eventBus
///         dataEventTask = makeEventTask(stream: { $0.dataEvents() },
///                                       handler: { [weak self] in await self?.handleDataEvent($0) })
///     }
///     deinit { dataEventTask?.cancel() }
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
