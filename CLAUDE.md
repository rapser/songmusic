# sinkmusic — guía de arquitectura

App iOS (SwiftUI + SwiftData) de música con descargas desde almacenamiento en la nube
(Google Drive / Mega), playlists, ecualizador y reproducción en segundo plano.

## Capas (Clean Architecture, por carpetas dentro de un único target)

```
Presentation  Views · ViewModels (@Observable) · UIModels · Coordinators
Domain        Entities (value types puros) · UseCases · RepositoryProtocols · ReadStores (protocolos)
Data          DTOs (@Model SwiftData) · DataSources (Local/Remote) · Repositories · Mappers · ReadStores (impl)
Infrastructure  Servicios de plataforma (audio, keychain, live activity, storage)
Core          EventBus · utilidades · extensiones · formatters
Application   sinkmusicApp · AppDelegate · DIContainer (composition root)
Features      Auth (módulo feature-first; ver nota abajo)
```

**Reglas de dependencia**
- Domain **no** conoce Data ni Infrastructure ni SwiftUI/SwiftData. Solo `Foundation`.
  Si un UseCase necesita algo, se declara un `...Protocol` en Domain y se implementa en Data.
- Nada de valores por defecto concretos en los `init` (`= FooRepositoryImpl()`): romperían la
  dirección de dependencias y crean un camino de construcción paralelo al `DIContainer`.
- Presentation depende de Domain (UseCases + ReadStores), nunca de Data directamente.

**Mapeo de 3 capas** (patrón fijo, ver `SongMapper` / `PlaylistMapper`):
`DTO ↔ Domain ↔ UI`. Los `Mapper` son el único sitio donde se cruza de una capa a otra.

## Persistencia — qué tecnología usar

| Dato | Tecnología |
|------|-----------|
| Datos de dominio (canciones, playlists, contadores) | **SwiftData** (`@Model` en `Data/DTOs/Local/`) |
| Preferencias de UI triviales y estado efímero (última posición de reproducción, curación de Inicio) | UserDefaults (`*RepositoryImpl` en `Data/Repositories/`) — *candidatos a migrar a SwiftData por consistencia* |
| Secretos (API keys, credenciales) | Keychain (`KeychainService`) |

- Toda entidad nueva se añade al `ModelContainer(for:)` en `sinkmusicApp`, `PreviewData` y
  `ReadStoreTestSupport.makeInMemoryContainer`.
- **Cambios de esquema**: añadir una entidad nueva e independiente es una migración aditiva
  segura. Modificar `SongDTO`/`PlaylistDTO` (tienen `@Attribute(.unique)`) es frágil con la
  migración implícita — requiere `VersionedSchema` + `SchemaMigrationPlan` explícitos.

## Reactividad

Los `ReadStore` de Data observan `ModelContext.didSave` vía `ModelContextChangeObserver`
(filtrado por nombre de entidad) y republican una señal `AsyncStream<Void>` (`changes()`).
Los ViewModels se suscriben en `init` con un `changesTask` y lo cancelan en `deinit`.
Los DataSources **no** notifican a la UI a mano.

Eventos puntuales (player, descargas, auth) van por `EventBus` (`Core/EventBus`), no por
el read-side reactivo.

## DI

`DIContainer` es el composition root (`Application/DI/DIContainer.swift`). `createShared()`
se llama una vez en `sinkmusicApp.init`; `configure(with: modelContext)` lo completa cuando
el `ModelContainer` está listo. Los factories `make*ViewModel()` arman el grafo.

## Nota: `Features/Auth`

`Auth` está organizado feature-first (todo junto: View, ViewModel, Strategy, Facade, State)
a diferencia del resto de la app, que es layer-first. Es deliberado por ahora — Auth es un
subsistema con estrategias intercambiables (Apple hoy; Firebase/Supabase/REST previstas).
Cualquier lógica de Auth nueva va aquí, no repartida por las capas.

## Tests

`xcodebuild test -scheme sinkmusic -destination 'platform=iOS Simulator,name=iPhone 17'`

- `sinkmusicTests/ReadStores` — tests de SwiftData reales en memoria (`ReadStoreTestSupport`).
- `sinkmusicTests/UseCases` y `sinkmusicTests/ViewModels` — con mocks (`sinkmusicTests/Mocks`).
- Los tests reactivos toman el `stream` **antes** de disparar el cambio y esperan con
  `fulfillment(of:timeout:)` (no `Task.sleep`).

## Deuda técnica conocida

Ver `/Users/rapser/.claude/plans/necesito-que-en-base-memoized-charm.md` (auditoría completa
con plan priorizado). Refactors grandes pendientes: cascada de reactividad, `SongUI` sin
trabajo pesado, partir `AudioPlayerService` y los ViewModels grandes, `songOrder` → entidad.
