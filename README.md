# SinkMusic

Aplicación de música para iOS con reproducción de audio de alta calidad, ecualizador, playlists,
descargas desde **Google Drive** o **MEGA**, reproducción en segundo plano, Live Activities y
CarPlay.

- **Swift 6** con *strict concurrency* (cero advertencias) · **SwiftUI** · **SwiftData** · `@Observable`
- **Clean Architecture por capas** + **MVVM** + **Inyección de dependencias pura** (sin frameworks)
- iOS **18.0+** · Xcode **26** · bundle id `com.rapser.musicaapp`

---

## Índice

1. [Características](#características)
2. [Arquitectura](#arquitectura)
   - [Capas y regla de dependencia](#capas-y-regla-de-dependencia)
   - [Estructura de carpetas](#estructura-de-carpetas)
   - [Mapeo de 3 capas (DTO ↔ Domain ↔ UI)](#mapeo-de-3-capas-dto--domain--ui)
   - [Flujo de datos: escritura vs. lectura reactiva](#flujo-de-datos-escritura-vs-lectura-reactiva)
   - [Dependency Injection](#dependency-injection)
   - [EventBus (solo eventos globales)](#eventbus-solo-eventos-globales)
   - [ReadStore (lectura reactiva de listas)](#readstore-lectura-reactiva-de-listas)
   - [Persistencia y migraciones](#persistencia-y-migraciones)
   - [Módulo Auth (Facade + Strategy)](#módulo-auth-facade--strategy)
   - [Concurrencia Swift 6](#concurrencia-swift-6)
3. [SOLID](#solid)
4. [Buenas prácticas aplicadas](#buenas-prácticas-aplicadas)
5. [Tests](#tests)
6. [Requisitos e instalación](#requisitos-e-instalación)
7. [Distribución a TestFlight](#distribución-a-testflight)
8. [Changelog · Autor · Licencia](#changelog--autor--licencia)

---

## Características

### Reproducción de audio
- `AVAudioEngine` + ecualizador de 6 bandas (60 Hz, 150 Hz, 400 Hz, 1 kHz, 2.4 kHz, 15 kHz) con presets
- Play/pause, siguiente, anterior, modo aleatorio y tres modos de repetición (off / all / one)
- Reproducción en segundo plano, Lock Screen y Control Center (`MPNowPlayingInfoCenter` + remote commands)
- Reanudación automática tras llamadas / Siri / alarmas (manejo de `AVAudioSession.interruptionNotification`)
- Pausa al desconectar auriculares; reconexión transparente del engine ante cambios de ruta de hardware
- Persistencia de la última canción y posición de reproducción

### Live Activities & Dynamic Island
- Reproductor en vivo con Dynamic Island (iPhone 14 Pro+), controles desde Lock Screen, artwork y metadatos en tiempo real

### Almacenamiento en la nube (Google Drive / MEGA)
- Dos proveedores seleccionables en Ajustes
- Sincronización a demanda con la carpeta configurada; descarga individual y "Descargar todo" (MEGA)
- Cola de descargas secuencial con límites por proveedor (actor + async/await); aviso al llegar al límite de MEGA (5 GB/día)
- Extracción de metadatos (ID3, artwork), escritura atómica del archivo, caché de imágenes en 3 tamaños (32×32, 64×64, full)
- Ruta local unificada en `DownloadFileStore` (`Documents/Music/<uuid>.m4a`, una sola definición)

### Playlists
- Creación y gestión; agregar/quitar canciones con gestos
- **Reordenamiento manual** arrastrando (drag-to-reorder), con actualización optimista y rollback si falla la persistencia
- El orden se guarda en la entidad **`PlaylistItemDTO { playlistID, songID, position }`** — consultable e imposible de desincronizar (antes era un CSV de UUIDs en `PlaylistDTO.songOrder`, ya *legacy*)
- Ranking "Canciones que más escuchas" con ventana de 7 días por canción (entidad `RankingWindowEntryDTO`)
- Curación de qué playlists aparecen en Inicio ("Editar inicio")

### Mini player y reproductor
- Color de fondo según la carátula (estilo Spotify); color dominante calculado una vez y cacheado en `SongDTO`
- Se oculta y limpia al borrar todas las descargas; progreso de descarga fluido (throttle por tiempo)

### Búsqueda
- Tiempo real con *debounce* (300 ms), filtrado por título/artista/álbum, paginación progresiva, estados vacíos contextuales

---

## Arquitectura

**Clean Architecture + MVVM + DI pura**, un único target de Xcode; las capas son convención de
carpetas. Compila en Swift 6 *strict concurrency* sin advertencias.

```
+------------------------------------------------------------------+
|                        PRESENTATION                              |
|   Views (SwiftUI)  <--  ViewModels (@Observable + @MainActor)    |
|                         UIModels · Coordinators                  |
+-----------------------------------|------------------------------+
                                    |  UseCases + ReadStoreProtocol
                                    v
+------------------------------------------------------------------+
|                          DOMAIN                                  |
|   Entities (value types puros)  ·  UseCases (lógica de negocio)  |
|   RepositoryProtocols  ·  ReadStoreProtocols  ·  DurationFormatter|
|   (solo Foundation — NADA de SwiftData / SwiftUI / Infra)        |
+-----------------------------------|------------------------------+
                                    |  Repositories (impl)
                                    v
+------------------------------------------------------------------+
|                           DATA                                   |
|   DTOs (@Model SwiftData)  ·  DataSources (Local/Remote)         |
|   Repositories  ·  Mappers  ·  ReadStores (impl)                 |
+-----------------------------------|------------------------------+
                                    |
                                    v
+------------------------------------------------------------------+
|                      INFRASTRUCTURE                              |
|   AudioPlayerService · NowPlayingCenter · AudioInterruptionObs.  |
|   KeychainService · LiveActivityService · MetadataService        |
|   DownloadFileStore · StorageManagementService                   |
+-----------------------------------|------------------------------+
                                    |
                                    v
+------------------------------------------------------------------+
|          APPLICATION  ·  DIContainer (composition root)          |
+------------------------------------------------------------------+
```

### Capas y regla de dependencia

- **Domain no conoce Data, Infrastructure, SwiftUI ni SwiftData.** Solo `Foundation`. Si un UseCase
  necesita algo externo, se declara un `...Protocol` en Domain y se implementa en Data/Infrastructure.
- **Nada de valores por defecto concretos en los `init`** (`= FooRepositoryImpl()`): rompería la
  dirección de dependencias y crearía un camino de construcción paralelo al `DIContainer`.
- **Presentation depende de Domain** (UseCases + ReadStores), nunca de Data directamente.
- El único cruce entre capas son los **Mappers**.

### Estructura de carpetas

```
sinkmusic/
├── Application/                     # Composition root
│   ├── DI/DIContainer.swift         # Único singleton — arma todo el grafo
│   ├── sinkmusicApp.swift           # Entry point; crea el ModelContainer
│   └── StorageErrorView.swift       # Pantalla si SwiftData no abre (en vez de fatalError)
│
├── Core/                            # Utilidades transversales
│   ├── Concurrency/ReactiveReload.swift   # Helper del bucle changesTask
│   ├── Errors/                      # AppError, SyncError (con userMessage)
│   ├── EventBus/                    # EventBus + Protocol + Observable + Events/
│   ├── Extensions/Color+Extension.swift   # Análisis de color dominante de carátula
│   └── Utils/ · Utilities/          # PreviewData, ViewModelLoadHelper, PlaceholderColors
│
├── Domain/                          # Reglas de negocio — SOLO Foundation
│   ├── Entities/                    # Song, Playlist (value types), *Error
│   ├── Formatting/DurationFormatter.swift # mm:ss / Xh Ym — único formateador
│   ├── RepositoryProtocols/         # Song, Playlist, CloudStorage, Credentials, Metadata,
│   │                                #   DownloadFileStore, RankingWindow, HomePlaylistLayout,
│   │                                #   PlaybackState
│   ├── ReadStores/                  # Home/Library/Playlist/Search ReadStoreProtocol (ISP)
│   ├── Interfaces/                  # AudioPlayerProtocol, MetadataServiceProtocol
│   └── UseCases/                    # Player, Library, Playlist, Download, Settings, Equalizer, Search
│
├── Data/
│   ├── DTOs/Local/                  # SongDTO, PlaylistDTO, PlaylistItemDTO,
│   │                                #   RankingWindowEntryDTO, AppSchema (VersionedSchema)
│   ├── DataSources/
│   │   ├── Local/                   # SongLocalDataSource, PlaylistLocalDataSource,
│   │   │                            #   RankingWindowLocalDataSource
│   │   ├── Remote/                  # GoogleDriveDataSource, MegaDataSource (+ APIClient,
│   │   │                            #   Crypto, DownloadSession, FolderMapper)
│   │   └── Protocols/               # GoogleDriveServiceProtocol, MegaServiceProtocol
│   ├── ReadStores/                  # Home/Library/Playlist/SearchReadStore + Support/
│   │   └── Support/ModelContextChangeObserver.swift  # Observa ModelContext.didSave (+ debounce)
│   ├── Mappers/                     # SongMapper, PlaylistMapper (DTO ↔ Domain ↔ UI)
│   └── Repositories/                # *RepositoryImpl + SyncErrorMapping (clasificación tipada)
│
├── Infrastructure/                  # Servicios de plataforma
│   ├── Protocols/                   # AudioPlayerServiceProtocol, Keychain, LiveActivity
│   └── Services/
│       ├── AudioPlayerService.swift        # Engine + EQ + timers de progreso
│       ├── NowPlayingCenter.swift          # MPNowPlayingInfo + remote commands
│       ├── AudioInterruptionObserver.swift # Pausa/reanuda ante interrupciones (delegate)
│       ├── DownloadFileStore.swift         # Única definición de Documents/Music/<uuid>.m4a
│       ├── KeychainService · LiveActivityService · MetadataService
│       └── ImageCompressionService · StorageManagementService · BackgroundSessionCompletion
│
├── Presentation/
│   ├── ViewModels/                  # Home, Library, Player, Playlist, Download, Search,
│   │                                #   Settings/{SettingsViewModel, HomePlaylistLayoutViewModel}
│   ├── UIModels/                    # SongUI, PlaylistUI (ya formateados para la vista)
│   ├── Coordinators/               # PlayerCoordinator
│   └── Views/                       # SwiftUI por feature
│
└── Features/
    └── Auth/                        # Feature-first (Facade + Strategy) — ver sección
```

### Mapeo de 3 capas (DTO ↔ Domain ↔ UI)

Patrón fijo (ver `SongMapper` / `PlaylistMapper`). Cada capa tiene su tipo y el `Mapper` es el
**único** sitio donde se cruza:

| Capa | Tipo | Ejemplo |
|------|------|---------|
| Data | `@Model` SwiftData | `SongDTO` — `@Attribute(.unique)` en `id`/`fileID` |
| Domain | value type puro | `Song` — con `with(...)` / `clearingLocalArtwork()` para copias inmutables |
| Presentation | value type ya formateado | `SongUI` — `duration: "03:45"`, `backgroundColor` resuelto (no se recalcula por render); `==`/`hash` no comparan los blobs de imagen |

### Flujo de datos: escritura vs. lectura reactiva

```
ESCRITURA (y consultas puntuales)
 View → ViewModel → UseCase → Repository → DataSource → ModelContext.save()

LECTURA REACTIVA DE LISTAS (Home / Library / Playlist / Search)
 ModelContext.save()
        │  ModelContext.didSave (NotificationCenter)
        ▼
 ModelContextChangeObserver  ── filtra por nombre de entidad + debounce 120 ms ──►  AsyncStream<Void>
        ▼
 ReadStore.changes()  →  ViewModel (ReactiveReload.loop)  →  vuelve a leer del mismo UseCase
        ▼                                                       (queries targeted, no getAll()+filter)
 View se re-renderiza

EVENTOS GLOBALES (login/logout, progreso de descarga, remote control)
 → EventBus (AsyncStream tipado) — sin relación con lo anterior
```

Los DataSources **no** notifican a la UI a mano: la reactividad "sale gratis" del `didSave`.

### Dependency Injection

DI **pura**, sin frameworks. `DIContainer` (`Application/DI/`) es el único singleton y el
*composition root*:

```swift
@MainActor
final class DIContainer {
    static private(set) var shared: DIContainer!

    static func createShared() -> DIContainer      // 1) en sinkmusicApp.init
    func configure(with modelContext: ModelContext) // 2) cuando el ModelContainer está listo

    // Core services (una vez) · Repositories y UseCases (lazy) · factories make*ViewModel()
    func makePlayerViewModel() -> PlayerViewModel
    func makeLibraryViewModel() -> LibraryViewModel
    // ...
}
```

Ningún `init` de Domain/Presentation trae dependencias concretas por defecto: **todo** se arma en
los `make*` del contenedor (o en `PreviewData` para los previews).

### EventBus (solo eventos globales)

Acotado a lo genuinamente transversal: **Auth**, **Playback** (Live Activity, remote control) y
**Download**. No se usa para reactividad de listas.

```swift
protocol EventBusProtocol {
    func emit(_ event: AuthEvent);  func authEvents() -> AsyncStream<AuthEvent>
    func emit(_ event: PlaybackEvent); func playbackEvents() -> AsyncStream<PlaybackEvent>
    func emit(_ event: DownloadEvent); func downloadEvents() -> AsyncStream<DownloadEvent>
}
```

Los ViewModels que escuchan eventos globales (Player, Download) adoptan `EventBusObservable` y
cancelan su task en `deinit`.

### ReadStore (lectura reactiva de listas)

Cada dominio tiene su **propio** `ReadStoreProtocol` pequeño (ISP — no uno genérico). La
implementación observa `ModelContext.didSave`, filtra por entidad relevante, y emite
`AsyncStream<Void>`. El ViewModel se re-suscribe con `ReactiveReload.loop` y cancela en `deinit`.

```swift
@MainActor
protocol LibraryReadStoreProtocol: AnyObject {
    func allSongs() async throws -> [Song]
    func stats() async throws -> LibraryStats
    func changes() -> AsyncStream<Void>
}

// En el ViewModel:
changesTask = ReactiveReload.loop(readStore.changes()) { [weak self] in
    await self?.loadSongs()
}
```

**Por qué no `@Query`:** los ViewModels son `@Observable` puros, no Views. `ModelContextChangeObserver`
hace ese trabajo a nivel de ViewModel.

### Persistencia y migraciones

| Dato | Tecnología |
|------|-----------|
| Datos de dominio (canciones, playlists, orden, contadores, ranking) | **SwiftData** (`@Model` en `Data/DTOs/Local/`) |
| Preferencias de UI triviales (última posición de reproducción, curación de Inicio) | UserDefaults (`*RepositoryImpl`) |
| Secretos (API keys, credenciales) | Keychain (`KeychainService`) |

**Esquema versionado.** `AppSchema.swift` define `AppSchemaV1: VersionedSchema` y
`AppMigrationPlan: SchemaMigrationPlan`. Los 4 `ModelContainer` (`sinkmusicApp`, `PreviewData` ×2,
`ReadStoreTestSupport`) se construyen con `AppSchemaV1.schema` + `migrationPlan: AppMigrationPlan.self`.
Registrar una entidad nueva = añadirla a **`AppSchemaV1.models`** (único sitio).

**Reglas de cambio de esquema:**
- Entidad nueva e **independiente** (keyed por `UUID`, sin `@Relationship` a `SongDTO`/`PlaylistDTO`)
  → aditiva y segura (así entraron `RankingWindowEntryDTO` y `PlaylistItemDTO`).
- Modificar `SongDTO` (tiene `@Attribute(.unique)`) → frágil: requiere `AppSchemaV2` + un
  `MigrationStage` en `AppMigrationPlan.stages`.
- **Migración de datos** (mover contenido de un campo viejo a una entidad nueva) → *backfill
  perezoso* en el DataSource en la primera lectura, **no** `MigrationStage.custom`.
  Ejemplo: `PlaylistLocalDataSource.syncedOrderItems` convierte el `songOrder` (CSV legacy) en
  filas `PlaylistItemDTO` la primera vez que se lee la playlist, y reconcilia el orden con la
  relación en cada acceso.

### Módulo Auth (Facade + Strategy)

`Features/Auth/` está organizado **feature-first** (todo junto) a diferencia del resto de la app
(*layer-first*). Es deliberado: Auth es un subsistema con estrategias intercambiables
(Apple hoy; Firebase/Supabase/REST previstas).

```
AuthState  ·  AuthStrategy (protocol + AppleAuthStrategy)  ·  AuthFacade (orquesta)
AuthEnvironment (dev/qa/prod)  ·  AuthStrategyFactory  ·  AuthViewModel  ·  AuthLoginView
```

### Concurrencia Swift 6

Compila con **cero advertencias** en *strict concurrency*. Cada tipo declara su aislamiento:

| Patrón | Dónde | Por qué |
|--------|-------|---------|
| `@MainActor class` | ViewModels, servicios de audio, DataSources | Estado de UI y de audio en el main thread |
| `private actor State` | `MegaDownloadState`, `GoogleDriveDownloadState` | Estado mutable de descargas concurrentes sin locks |
| `nonisolated func` | Delegates de AVFoundation / URLSession / NotificationCenter | El sistema los llama en threads arbitrarios |
| `Task { @MainActor [weak self] in }` | Dentro de callbacks `nonisolated` | Puente de vuelta al main actor |
| `nonisolated(unsafe) var token` | Tokens de `NotificationCenter` | No `Sendable`; `removeObserver` es seguro desde cualquier hilo |
| `[weak self]` en todos los `Task` | Todos los closures concurrentes | Evita retención de ciclos; requerido por Swift 6 |

---

## SOLID

| Principio | Cómo se aplica aquí |
|-----------|---------------------|
| **S**ingle Responsibility | Una responsabilidad por tipo. `AudioPlayerService` se partió en engine + `NowPlayingCenter` (MPNowPlayingInfo + remote commands) + `AudioInterruptionObserver` (interrupciones). La curación de Inicio salió de `PlaylistViewModel` a `HomePlaylistLayoutViewModel`. |
| **O**pen/Closed | Extensión vía protocolos: nuevos proveedores de nube (`GoogleDriveServiceProtocol`/`MegaServiceProtocol`), nuevas estrategias de auth (`AuthStrategy`), sin tocar el código existente. |
| **L**iskov Substitution | Toda implementación es intercambiable por su protocolo; los tests inyectan mocks sin condicionales. |
| **I**nterface Segregation | Protocolos pequeños y por dominio: 4 `ReadStoreProtocol` distintos (no uno genérico), `DownloadFileStoreProtocol` con 2 métodos, `AudioInterruptionDelegate` con lo justo. |
| **D**ependency Inversion | Todas las dependencias se inyectan por constructor desde el `DIContainer`. Domain declara `...Protocol`; Data/Infrastructure implementan. Domain no importa SwiftData/SwiftUI. |

**Además (patrones):** Repository, Mapper, Facade + Strategy (Auth), Coordinator (`PlayerCoordinator`),
Observer (`ModelContextChangeObserver`), Composition Root (`DIContainer`).

---

## Buenas prácticas aplicadas

- **Higiene de código:** sin `try!`, sin `as!`, sin `print(` (verificado). SwiftLint activo
  (`.swiftlint.yml`: `file_length`, `type_body_length`, `cyclomatic_complexity`… en `warning`).
- **Sin `fatalError` en el arranque:** si el `ModelContainer` no abre se muestra `StorageErrorView`
  (antes: crash-loop). El `fatalError` restante en `DIContainer` es un *guard* de error de
  programador (llamar a un factory antes de `configure`), inalcanzable en el path de fallo real.
- **Sin dependencias concretas por defecto en los `init`** — todo pasa por el `DIContainer`.
- **Value types inmutables en Domain:** `Song.with(...)` en vez de reconstruir con 14 argumentos.
- **Un solo punto de verdad para cada cosa transversal:**
  - Formato de duración → `DurationFormatter` (antes 6 implementaciones).
  - Ruta del archivo descargado → `DownloadFileStore` (antes 3 copias + `switch` por proveedor).
  - Copiado de `SongDTO` en `update()` → `SongDTO.apply(from:)` (antes 15 campos a mano).
  - Bucle de suscripción reactiva → `ReactiveReload.loop` (antes boilerplate ×4).
- **Errores tipados en la frontera de Data:** `SyncError` (con `userMessage`) mapea
  `URLError`/HTTP status → casos concretos, en vez de `error.localizedDescription.contains("401")`.
- **Rendimiento del read-side:** `ModelContextChangeObserver` filtra por entidad y hace *debounce*
  (120 ms) para colapsar ráfagas de `save()`; los ViewModels usan guardas de asignación
  (`if x != new { x = new }`) para no re-renderizar listas sin cambios; `SongUI` no lleva
  `playCount` (contador volátil) ni compara blobs de imagen en `==`.
- **Queries targeted** en los ReadStore (no `getAll()` + filtro en memoria).

---

## Tests

`sinkmusicTests/` — **~373 tests**, todos `@MainActor` (Swift 6 strict concurrency).

```
sinkmusicTests/
├── Helpers/TestFixtures.swift          — Song.make(), Playlist.make(), CloudFile.make()
├── Mocks/                              — un mock por protocolo, con contadores/resultados configurables
│   ├── MockSongRepository · MockPlaylistRepository · MockCloudStorageRepository
│   ├── MockAudioPlayerService (síncrono) · MockLiveActivityService · MockMetadataRepository
│   ├── MockCredentialsRepository · MockEventBus (Auth/Playback/Download)
│   ├── MockHomePlaylistLayoutRepository · MockPlaybackStateRepository
│   └── Mock{Home,Library,Playlist,Search}ReadStore
├── UseCases/                           — lógica de dominio con mocks en memoria (sin SwiftData/red/FS)
│   Player 29 · Library 25 · Playlist 34 · Search 21 · Download 25 · Equalizer 10 · Settings 41
├── ViewModels/                         — Home, Library, Player, Playlist, Download, Search,
│   Settings, Equalizer, HomePlaylistLayout (10)
├── Infrastructure/                     — AudioPlayerService (10) · NowPlayingCenter (6) ·
│   AudioInterruptionObserver (6)   [Now Playing real vía MPNowPlayingInfoCenter.default()]
├── Data/                               — SwiftDataMigration (3) · PlaylistOrderPersistence (5) ·
│   RankingWindowRepositoryImpl (5) · MegaFolderMapper
├── Coordinators/PlayerCoordinatorTests
├── Core/DownloadFailureClassifierTests
└── ReadStores/                         — integración SwiftData REAL en memoria (sin mocks)
    ├── ReadStoreTestSupport.swift      — makeInMemoryContainer() (usa AppSchemaV1.schema),
    │                                     insertSong(), insertPlaylist()
    ├── {Home,Library,Playlist,Search}ReadStoreTests
    ├── ModelContextChangeObserverTests
    └── ReactiveFlowTests               — flujos end-to-end (descarga, borrado, playlist, búsqueda)
```

**Convenciones:**
- UseCases/ViewModels → mocks. ReadStores/Data → `ModelContainer` real en memoria.
- Los tests reactivos toman el `stream` **antes** de disparar el cambio y esperan con
  `fulfillment(of:timeout:)` — nunca `Task.sleep`.
- `ModelContext` no retiene fuerte a su `ModelContainer`: el test debe guardar
  `let container = try ReadStoreTestSupport.makeInMemoryContainer()` durante toda su ejecución.
- Migración: `SwiftDataMigrationTests` abre un store "heredado" (sin plan), lo reabre con
  `AppMigrationPlan` y verifica que no se pierden canciones, playlists ni el orden.

**Ejecutar:**

```bash
# Xcode
Cmd+U

# CLI
xcodebuild test -scheme sinkmusic \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Lint
brew install swiftlint   # una vez
swiftlint                 # desde la raíz del repo
```

---

## Requisitos e instalación

- **iOS 18.0+**, **Xcode 26** (Swift 6)
- Cuenta de Apple Developer (para firmar y para TestFlight)
- Proveedor de nube: Google Drive (credenciales de API en Cloud Console) **o** MEGA (URL de carpeta pública)
- Dispositivo físico recomendado para Live Activities / Dynamic Island

```bash
git clone https://github.com/rapser/sinkmusic.git
cd sinkmusic
open sinkmusic.xcodeproj
```

1. **Signing & Capabilities** → selecciona tu *Team*.
2. Configura el proveedor de nube en Ajustes de la app (credenciales Google Drive o URL MEGA / escáner QR).
3. Compila y ejecuta (`Cmd+R`).

---

## Distribución a TestFlight

### 0. Prerrequisitos (una vez)

1. En [App Store Connect](https://appstoreconnect.apple.com/) → **Apps** → **+** → crea la app
   con el bundle id `com.rapser.musicaapp`.
2. En Xcode, target `sinkmusic` → **Signing & Capabilities**: *Automatically manage signing*,
   *Team* correcto. Verifica que las *capabilities* (Background Modes: Audio, Push si aplica,
   App Groups para la Live Activity extension) coinciden con el perfil de App Store.
3. (Para subir por CLI) crea una **App Store Connect API Key**:
   App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** →
   genera una clave con rol *App Manager*. Descarga `AuthKey_XXXXXXXXXX.p8` y guárdala en
   `~/.appstoreconnect/private_keys/`. Anota el **Key ID** y el **Issuer ID**.

### 1. Sube el número de build

Cada envío a TestFlight necesita un **build único** para la misma versión:

- **Version** (`MARKETING_VERSION`) — visible al usuario, p. ej. `1.2.0`. Solo cambia en releases.
- **Build** (`CURRENT_PROJECT_VERSION`) — incrementa **siempre** (`22` → `23` → …).

En Xcode: target → **General** → *Identity*. O por CLI:

```bash
xcrun agvtool next-version -all          # incrementa el build
xcrun agvtool new-marketing-version 1.2.0  # (solo si cambias la versión)
```

Haz commit del bump (`chore: set version`).

### 2A. Ruta recomendada — Xcode Organizer (GUI)

1. Selecciona el destino **Any iOS Device (arm64)** (no un simulador).
2. **Product → Archive**. Al terminar se abre el **Organizer**.
3. Selecciona el archive → **Distribute App** → **App Store Connect** → **Upload**.
4. Opciones: deja *Upload your app's symbols* y *Manage Version and Build Number* si quieres que
   Xcode gestione el build; firma con *Automatically manage signing*.
5. **Upload**. Cuando termine, el build aparece en App Store Connect → tu app → **TestFlight**
   en estado *Processing* (5–30 min).

### 2B. Ruta CLI (para CI o scripts)

```bash
# 1) Archive
xcodebuild -scheme sinkmusic -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/sinkmusic.xcarchive \
  clean archive

# 2) Exportar el .ipa  (necesita ExportOptions.plist, ver abajo)
xcodebuild -exportArchive \
  -archivePath build/sinkmusic.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

# 3) Subir a TestFlight con la API Key
xcrun altool --upload-app -f build/export/sinkmusic.ipa -t ios \
  --apiKey XXXXXXXXXX --apiIssuer 11111111-2222-3333-4444-555555555555
# (alternativa moderna: xcrun notarytool no aplica a iOS App Store;
#  también puedes usar la app Transporter o `fastlane pilot upload`)
```

`ExportOptions.plist` mínimo:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>            <string>app-store-connect</string>
    <key>teamID</key>            <string>TU_TEAM_ID</string>
    <key>uploadSymbols</key>     <true/>
    <key>signingStyle</key>      <string>automatic</string>
</dict>
</plist>
```

> En Xcode &lt; 15 el `method` es `app-store`. Desde Xcode 15/16 se usa `app-store-connect`.

### 2C. fastlane (opcional)

```ruby
# fastlane/Fastfile
lane :beta do
  increment_build_number(xcodeproj: "sinkmusic.xcodeproj")
  build_app(scheme: "sinkmusic", export_method: "app-store")
  upload_to_testflight(
    api_key_path: "fastlane/asc_key.json",   # Key ID + Issuer ID + .p8
    skip_waiting_for_build_processing: true
  )
end
```

### 3. Tras la subida (en App Store Connect → TestFlight)

1. Espera a que el build pase de *Processing* a listo.
2. **Export Compliance**: responde el cuestionario de cifrado (esta app usa HTTPS estándar y el
   cifrado de MEGA; normalmente califica para exención — si añades
   `ITSAppUsesNonExemptEncryption = NO` en el `Info.plist` no te lo vuelve a preguntar).
3. **Testers internos** (hasta 100, miembros del equipo): añade el build al grupo interno →
   disponible en minutos, sin revisión.
4. **Testers externos**: crea un grupo, añade emails o un *public link*, adjunta el build →
   requiere una **Beta App Review** (suele ser < 24 h la primera vez).
5. Rellena *What to Test* y la información de contacto beta.

### Problemas frecuentes

| Síntoma | Causa / arreglo |
|--------|-----------------|
| "No suitable application records were found" | La app no existe en App Store Connect con ese bundle id → créala primero. |
| El build no aparece en TestFlight | Sigue *Processing*; revisa el email de Apple por *Invalid Binary* (símbolos, íconos, `Info.plist`). |
| "Missing Compliance" | Contesta el cuestionario de export compliance o añade `ITSAppUsesNonExemptEncryption`. |
| Rechazo por *Missing Purpose String* | Falta una key `NS...UsageDescription` en el `Info.plist` (micrófono, red local, etc.). |
| Build duplicado | No incrementaste `CURRENT_PROJECT_VERSION`. |

---

## Changelog · Autor · Licencia

- Historial completo: [CHANGELOG.md](./CHANGELOG.md)
- Guía de arquitectura para colaboradores/agentes: [CLAUDE.md](./CLAUDE.md)

**Miguel Tomairo (rapser)** — GitHub [@rapser](https://github.com/rapser)

Proyecto privado. Todos los derechos reservados.
