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

- Toda entidad nueva se añade a `AppSchemaV1.models` (`Data/DTOs/Local/AppSchema.swift`) — es
  el único sitio: `sinkmusicApp`, `PreviewData` y `ReadStoreTestSupport` construyen el
  `ModelContainer` con `AppSchemaV1.schema` + `migrationPlan: AppMigrationPlan.self`.
- **Cambios de esquema**: añadir una entidad nueva e independiente (keyed por UUID, sin
  `@Relationship` a `SongDTO`/`PlaylistDTO`) es aditivo y seguro — se añade a `AppSchemaV1.models`.
  Modificar `SongDTO` (`@Attribute(.unique)` en `id`/`fileID`) es frágil: requiere un
  `AppSchemaV2` + `MigrationStage` en `AppMigrationPlan.stages`. Migraciones de datos (mover
  contenido de un campo viejo a una entidad nueva) se hacen con **backfill perezoso en el
  DataSource** en la primera lectura, no con `MigrationStage.custom` (ver `PlaylistItemDTO` /
  `PlaylistLocalDataSource.syncedOrderItems`).

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

Resumen inline y no un enlace: la auditoría anterior vivía en un archivo fuera del repo que
acabó desapareciendo, dejando esta sección apuntando a una ruta muerta.

**Fan-out del read-side — resuelto el camino caliente.** Dar al play escribía
`playCount`/`lastPlayedAt` en `SongDTO`, y las cuatro tiendas vigilan esa entidad: cuatro
señales por reproducción, con Biblioteca, Playlists y Búsqueda recargando enteras sin usar
el dato. El contador vive ahora en `SongPlayStatsDTO` (entidad independiente, aditiva,
mismo patrón que `RankingWindowEntryDTO`), que solo vigila Inicio. Medido en
`sinkmusicTests/ReadStores/ReadStoreFanOutTests.swift`: **de 4 señales a 1**, y una
escritura real sobre la canción sigue despertando a las cuatro, que es correcto.

Queda, con mucho menos valor ahora: unificar los cuatro `ModelContextChangeObserver` en
uno con señal tipada por entidad (un debounce en vez de cuatro, y adiós a los nombres de
entidad como literales de string). SwiftData History (`fetchHistory`, iOS 18+)
probablemente no vale lo que cuesta: obliga a gestionar y purgar transacciones.

**Al tocar el esquema**: los campos viejos de `SongDTO` siguen ahí a propósito —quitarlos
exigiría `AppSchemaV2`— y son la semilla del backfill perezoso. Cualquier cambio de esquema
se prueba migrando **desde una build anterior con datos reales**, no solo en instalación
limpia.

**Caminos duplicados — lo único grande que queda.** Cada dato se recarga aún por dos vías:
recarga imperativa tras mutar (`PlaylistViewModel` la repite en 11 métodos,
`LibraryViewModel` en 3) y la señal `changes()` ~120 ms después, que ya las cubre todas.
Hay que elegir **una** vía por dato. También sigue la cascada de `MainAppView`, con
`onPlayingIDChanged` llamado desde tres sitios y salvado por un guard de idempotencia.
`BulkReloadGate` ya se usa en las tres operaciones masivas que existen
(`downloadMultiple`, `clearLibrary`, `deleteSongs`).

**Responsabilidades — hecho.** El EQ fuera de `AudioPlayerService` (`AudioEqualizer`), la
cola fuera de `PlayerViewModel` (`PlaybackQueue` en Domain), `DownloadQueueManager`
inyectado desde el DI, `SettingsUseCases` partido en tres (`CloudCredentialsUseCases` /
`AppDataUseCases` / `AppInfoUseCases`), la curaduría de Inicio fuera del CRUD de playlists
(`HomePlaylistLayoutUseCases`) y las agregaciones fuera de Búsqueda
(`LibraryAggregationUseCases`). El modelo a seguir está en `Features/Auth`: Strategy +
Factory + Facade + State.

**Main actor.** Hecho: el color dominante se calcula al ingerir
(`MetadataService` → `DominantColorService`, fuera del main actor) y el mapper solo lee lo
persistido; la carátula del reproductor se decodifica a 1024 px fuera del main actor
(`ArtworkDecoder`). Para canciones anteriores a ese cambio queda el relleno perezoso de
`LibraryViewModel.persistDominantColorIfNeeded`.

**Reactividad — decidido, no revisar sin motivo.** `Observations` (SE-0475) es iOS 26+ y el
target es iOS 18, así que no es una alternativa; además observa *estado* y fusiona cambios
de la misma transacción, por lo que no sirve para eventos discretos como `songFinished`.
El `EventBus` sobre `AsyncStream` es la herramienta correcta aquí.
