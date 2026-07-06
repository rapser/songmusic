//
//  ViewModelLoadHelper.swift
//  sinkmusic
//

import Foundation

/// Elimina el boilerplate `do { assign(map(try await fetch())) } catch { onError(error) }`
/// que se repite en métodos de carga de ViewModels.
///
/// Uso típico (dentro de un ViewModel @MainActor):
/// ```swift
/// private func loadPlaylists() async {
///     await loadAndAssign(
///         fetch: { try await playlistUseCases.getAllPlaylists() },
///         map: { $0.map(PlaylistMapper.toUI) },
///         assign: { playlists = $0 },
///         onError: { logger.error("Error: \($0)") }
///     )
/// }
/// ```
@MainActor
func loadAndAssign<E, U>(
    fetch: () async throws -> [E],
    map: ([E]) -> [U],
    assign: ([U]) -> Void,
    onError: ((Error) -> Void)? = nil
) async {
    do { assign(map(try await fetch())) }
    catch { onError?(error) }
}
