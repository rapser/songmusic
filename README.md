# SinkMusic

Una aplicación de música moderna para iOS con reproducción de audio de alta calidad, gestión de playlists, integración con CarPlay y sincronización con **Google Drive** o **MEGA**.

## Características

### Reproducción de audio
- Reproduccion con AVAudioEngine y ecualizador de 6 bandas
- Controles de reproduccion avanzados (play/pause, siguiente, anterior)
- Modo aleatorio y tres modos de repeticion (off, all, one)
- Soporte para reproduccion en background
- Integracion con Lock Screen y Control Center
- Reanudacion automatica despues de llamadas telefonicas (comportamiento tipo Spotify)
- Pausa automatica al desconectar auriculares
- Manejo robusto de interrupciones de audio (llamadas, alarmas, Siri, etc.)
- Reconexión transparente del engine ante cambios de ruta de hardware (`AVAudioEngineConfigurationChange`) — sin chasquidos al abrir teclado

### Live Activities & Dynamic Island
- Reproductor en vivo con Dynamic Island (iPhone 14 Pro+)
- Controles de reproduccion desde Lock Screen
- Artwork y metadatos en tiempo real

### Almacenamiento en la nube (Google Drive / MEGA)
- **Dos proveedores**: Google Drive o MEGA (selección en Configuración)
- Sincronización a demanda con la carpeta configurada
- **Descarga individual** por canción y **Descargar todo** (solo con MEGA)
- Cola de descargas secuencial con límites por proveedor (Swift 6: actor + async/await)
- Sincronización por lotes para reducir `save()` repetidos y hacer más fluida la actualización de la biblioteca
- Aviso al usuario cuando se alcanza el límite de MEGA (5 GB/día) y limpieza de estado
- Extracción automática de metadatos (ID3, artwork); escritura atómica del archivo para evitar errores de formato
- Gestión de caché de imágenes (3 tamaños: 32×32, 64×64, full)

### Playlists
- Creacion y gestion de playlists personalizadas
- Agregar/remover canciones con gestos intuitivos
- **Reordenamiento manual** arrastrando canciones directamente (drag-to-reorder con handle `≡`)
- Orden persistido de forma explícita (campo `songOrder` en SwiftData para orden determinista)
- Actualización optimista del orden con rollback automático si falla la persistencia
- Contador de reproducciones y ultimas canciones reproducidas
- Grid view estilo Spotify con top songs carousel

### Ecualizador
- 6 bandas ajustables (60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 15kHz)
- Presets predefinidos (Rock, Pop, Jazz, Clasica, etc.)
- Aplicacion en tiempo real sin interrumpir reproduccion

### Mini player y reproductor
- Color de fondo del mini player según la **carátula** de la canción (estilo Spotify)
- Color dominante calculado la primera vez y guardado para siguientes reproducciones
- Progreso de descarga fluido (throttle por tiempo) hasta 100%
- Cambio de canción optimizado para reducir latencia entre pistas

### Reactividad
- UI reactiva con `@Observable` + `@MainActor` en los ViewModels
- Read-stores reactivos basados en `ModelContext.didSave` para refrescar solo lo que cambió
- Evita polling innecesario en Home, Library, Playlist y Search

### Búsqueda
- Búsqueda en tiempo real con debouncing (300 ms)
- Filtrado por título, artista y álbum
- Paginación progresiva (50 resultados iniciales, +30 por scroll)
- Estados vacíos contextuales (sin resultados vs. sin descargas)

## Arquitectura

Este proyecto implementa **Clean Architecture + MVVM** con **Dependency Injection pura** siguiendo los principios **SOLID** y usando **Swift 6** con **strict concurrency** verificada por el compilador.

La capa de lectura usa `ReadStore` reactivos para conectar SwiftData con la UI sin acoplar la presentación al EventBus global. El EventBus queda reservado para eventos verdaderamente transversales como reproducción, descargas y autenticación.

### Diagrama de Arquitectura

```
+------------------------------------------------------------------+
|                        PRESENTATION LAYER                         |
|  +------------------+     +-----------------------------------+   |
|  |      Views       |<----|           ViewModels              |   |
|  |    (SwiftUI)     |     |   (@Observable + @MainActor)      |   |
|  +------------------+     +----------------+------------------+   |
+-----------------------------------|-------------------------------+
                                    |
                                    | UseCases
                                    v
+------------------------------------------------------------------+
|                         DOMAIN LAYER                              |
|  +------------------+     +-----------------------------------+   |
|  |     Entities     |     |            UseCases               |   |
|  | (Business Models)|     |      (Business Logic)             |   |
|  +------------------+     +----------------+------------------+   |
|  +------------------+                      |                      |
|  |    Protocols     |<---------------------+                      |
|  | (Repository Abs) |                                             |
|  +------------------+                                             |
+-----------------------------------|-------------------------------+
                                    |
                                    | Repositories
                                    v
+------------------------------------------------------------------+
|                          DATA LAYER                               |
|  +------------------+     +-----------------------------------+   |
|  |      DTOs        |     |          Repositories             |   |
|  | (Data Transfer)  |     |      (Implementations)            |   |
|  +------------------+     +----------------+------------------+   |
|  +------------------+                      |                      |
|  |    DataSources   |<---------------------+                      |
|  | (Local/Remote)   |                                             |
|  +------------------+                                             |
+------------------------------------------------------------------+
                                    |
                                    v
+------------------------------------------------------------------+
|                      INFRASTRUCTURE LAYER                         |
|  +------------------+     +-----------------------------------+   |
|  |    Services      |     |           Protocols               |   |
|  | (AudioPlayer,    |     |    (Service Abstractions)         |   |
|  |  Keychain, etc)  |     |                                   |   |
|  +------------------+     +-----------------------------------+   |
+------------------------------------------------------------------+
                                    |
                                    v
+------------------------------------------------------------------+
|                      DEPENDENCY INJECTION                         |
|  +------------------------------------------------------------+  |
|  |                      DIContainer                            |  |
|  |  (Unico punto de entrada - Crea todas las dependencias)    |  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
```

### Estructura de Carpetas

```
sinkmusic/
|
+-- Application/                    # Punto de entrada de la app
|   +-- DI/
|   |   +-- DIContainer.swift       # Contenedor principal de DI
|   +-- sinkmusicApp.swift          # Entry point SwiftUI
|
+-- Core/                           # Utilidades compartidas
|   +-- Errors/                     # Errores de dominio
|   |   +-- AppError.swift
|   |   +-- SyncError.swift
|   +-- EventBus/                   # Bus de eventos SOLO para lo global/cross-cutting
|   |   +-- EventBus.swift          # Implementacion
|   |   +-- EventBusProtocol.swift  # Abstraccion
|   |   +-- EventBusObservable.swift # Mixin para ViewModels que escuchan eventos globales
|   |   +-- Events/
|   |       +-- AuthEvent.swift
|   |       +-- DownloadEvent.swift
|   |       +-- PlaybackEvent.swift
|   +-- Extensions/
|   |   +-- Color+Extension.swift
|   +-- Utils/
|       +-- PreviewData.swift       # Datos para SwiftUI Previews
|
+-- Domain/                         # Capa de Dominio (Reglas de Negocio)
|   +-- Entities/                   # Entidades de negocio puras
|   |   +-- Cloud/
|   |   |   +-- CloudFileEntity.swift
|   |   +-- Song/
|   |   |   +-- SongEntity.swift
|   |   |   +-- SongError.swift
|   |   +-- Playlist/
|   |       +-- PlaylistEntity.swift
|   |       +-- PlaylistError.swift
|   +-- RepositoryProtocols/        # Abstracciones de repositorios
|   |   +-- SongRepositoryProtocol.swift
|   |   +-- PlaylistRepositoryProtocol.swift
|   |   +-- AudioPlayerRepositoryProtocol.swift
|   |   +-- CloudStorageRepositoryProtocol.swift
|   |   +-- CredentialsRepositoryProtocol.swift
|   |   +-- MetadataRepositoryProtocol.swift
|   +-- ReadStores/                 # Protocolos de lectura reactiva (uno por dominio, ISP)
|   |   +-- HomeReadStoreProtocol.swift
|   |   +-- LibraryReadStoreProtocol.swift
|   |   +-- PlaylistReadStoreProtocol.swift
|   |   +-- SearchReadStoreProtocol.swift
|   +-- UseCases/                   # Casos de uso
|   |   +-- Player/
|   |   |   +-- PlayerUseCases.swift
|   |   +-- Library/
|   |   |   +-- LibraryUseCases.swift
|   |   +-- Playlist/
|   |   |   +-- PlaylistUseCases.swift
|   |   +-- Download/
|   |   |   +-- DownloadUseCases.swift
|   |   +-- Settings/
|   |       +-- SettingsUseCases.swift
|   +-- Interfaces/                 # Protocolos de servicios
|       +-- AudioPlayerProtocol.swift
|       +-- MetadataServiceProtocol.swift
|
+-- Data/                           # Capa de Datos
|   +-- DTOs/                       # Data Transfer Objects
|   |   +-- Local/
|   |   |   +-- SongDTO.swift       # @Model SwiftData
|   |   |   +-- PlaylistDTO.swift   # @Model SwiftData
|   |   +-- Remote/
|   |       +-- GoogleDriveFileDTO.swift
|   +-- DataSources/                # Fuentes de datos
|   |   +-- Local/
|   |   |   +-- SongLocalDataSource.swift
|   |   |   +-- PlaylistLocalDataSource.swift
|   |   +-- Remote/
|   |   |   +-- GoogleDriveDataSource.swift
|   |   +-- Protocols/
|   |       +-- GoogleDriveServiceProtocol.swift
|   +-- ReadStores/                 # Implementaciones reactivas de los ReadStore
|   |   +-- HomeReadStore.swift
|   |   +-- LibraryReadStore.swift
|   |   +-- PlaylistReadStore.swift
|   |   +-- SearchReadStore.swift
|   |   +-- Support/
|   |       +-- ModelContextChangeObserver.swift  # Observa ModelContext.didSave
|   +-- Mappers/                    # Conversores DTO <-> Entity
|   |   +-- SongMapper.swift
|   |   +-- PlaylistMapper.swift
|   +-- Repositories/               # Implementaciones de repositorios
|       +-- SongRepositoryImpl.swift
|       +-- PlaylistRepositoryImpl.swift
|       +-- AudioPlayerRepositoryImpl.swift
|       +-- CloudStorageRepositoryImpl.swift
|       +-- CredentialsRepositoryImpl.swift
|       +-- MetadataRepositoryImpl.swift
|
+-- Infrastructure/                 # Servicios de infraestructura
|   +-- Protocols/                  # Abstracciones de servicios
|   |   +-- AudioPlayerServiceProtocol.swift
|   |   +-- KeychainServiceProtocol.swift
|   |   +-- LiveActivityServiceProtocol.swift
|   +-- Services/                   # Implementaciones
|       +-- AudioPlayerService.swift
|       +-- KeychainService.swift
|       +-- LiveActivityService.swift
|       +-- MetadataService.swift
|       +-- StorageManagementService.swift
|
+-- Presentation/                   # Capa de Presentacion
|   +-- ViewModels/                 # ViewModels (@Observable)
|   |   +-- Player/
|   |   |   +-- PlayerViewModel.swift
|   |   +-- Library/
|   |   |   +-- LibraryViewModel.swift
|   |   +-- Home/
|   |   |   +-- HomeViewModel.swift
|   |   +-- Playlist/
|   |   |   +-- PlaylistViewModel.swift
|   |   +-- Download/
|   |   |   +-- DownloadViewModel.swift
|   |   +-- Settings/
|   |   |   +-- SettingsViewModel.swift
|   |   +-- Search/
|   |       +-- SearchViewModel.swift
|   +-- Views/                      # Vistas SwiftUI
|       +-- Main/
|       |   +-- MainAppView.swift
|       +-- Home/
|       |   +-- HomeView.swift
|       +-- Player/
|       |   +-- PlayerView.swift
|       |   +-- Components/
|       +-- Library/
|       |   +-- LibraryView.swift
|       +-- Playlist/
|       |   +-- PlaylistView.swift
|       |   +-- PlaylistDetailView.swift
|       +-- Settings/
|       |   +-- SettingsView.swift
|       +-- Login/
|           +-- LoginView.swift
|
+-- Features/                       # Modulos de funcionalidad aislados
    +-- Auth/                       # Modulo de Autenticacion (Facade + Strategy)
        +-- AuthState.swift         # Estados, AuthUser, AuthProvider, AuthError
        +-- AuthStrategy.swift      # Protocol + AppleAuthStrategy
        +-- AuthFacade.swift        # Facade principal (orquesta todo)
        +-- AuthEnvironment.swift   # Configuracion de ambientes (dev/qa/prod)
        +-- AuthStrategyFactory.swift # Factory para crear estrategias
        +-- AuthViewModel.swift     # ViewModel simplificado para SwiftUI
        +-- AuthLoginView.swift     # Vista de login con Sign In with Apple
```

### Flujo de Datos

Escrituras y lecturas puntuales van por el camino clásico (UseCase → Repository → DataSource).
La reactividad de listas (Home/Library/Playlist/Search) **no** pasa por EventBus: el ViewModel
lee de su `ReadStore`, que se entera solo cuando SwiftData guarda algo relevante.

```
Escritura:
+-------+     +----------+     +----------+     +------------+     +------------+
| View  | --> | ViewModel| --> | UseCase  | --> | Repository | --> | DataSource |
+-------+     +----------+     +----------+     +------------+     +-----+------+
                                                                          |
                                                                          v
                                                                 ModelContext.save()

Lectura reactiva:
+-------+     +----------+     +-----------+     +----------+
| View  | <-- | ViewModel| <-- | ReadStore | <-- | UseCase  |  (mismo UseCase de arriba, solo lectura)
+-------+     +----------+     +-----+-----+     +----------+
                                      ^
                                      | ModelContext.didSave (NotificationCenter)
                                      +---------------------------------------------+
                                                                                     |
                                                                          ModelContext.save()

Eventos globales (Auth/Playback/Download) siguen usando EventBus, sin relación con lo anterior.
```

1. **View** llama acción en **ViewModel**
2. **ViewModel** ejecuta **UseCase** para escrituras y consultas puntuales
3. **UseCase** coordina **Repositories** → **DataSources** → `ModelContext.save()`
4. Cada **ReadStore** (uno por dominio: Home/Library/Playlist/Search) observa `ModelContext.didSave`
   y, si la entidad afectada le importa, emite una señal `AsyncStream<Void>`
5. El **ViewModel** suscrito a esa señal vuelve a leer del **ReadStore** (que delega al mismo
   **UseCase**, con queries targeted) y actualiza su estado
6. **View** se re-renderiza automáticamente
7. Para lo genuinamente global (login/logout, progreso de descarga, remote control) el flujo
   sigue siendo **EventBus** — ver sección siguiente

### Dependency Injection

El proyecto usa **Inyeccion de Dependencias pura** sin frameworks externos.

**DIContainer** es el unico singleton permitido y actua como punto de entrada:

```swift
@MainActor
final class DIContainer {
    static let shared = DIContainer()

    // Core Services (creados una vez)
    var eventBus: EventBusProtocol
    var keychainService: KeychainServiceProtocol
    var audioPlayerService: AudioPlayerServiceProtocol

    // Auth Module (Facade + Strategy)
    var authViewModel: AuthViewModel  // Singleton compartido

    // Repositories (lazy)
    var songRepository: SongRepositoryProtocol
    var playlistRepository: PlaylistRepositoryProtocol
    // ...

    // UseCases (lazy)
    var playerUseCases: PlayerUseCases
    var libraryUseCases: LibraryUseCases
    // ...

    // ViewModel Factories
    func makePlayerViewModel() -> PlayerViewModel
    func makeLibraryViewModel() -> LibraryViewModel
    func makeAuthViewModel() -> AuthViewModel  // Retorna singleton
    // ...
}
```

### EventBus (solo eventos globales/cross-cutting)

El EventBus **no** se usa para la reactividad de listas — eso lo cubren los `ReadStore`
(ver sección siguiente). Queda acotado a lo que es genuinamente transversal a toda la app:
autenticación, reproducción (Live Activity, remote control) y descargas.

```swift
// Protocolo para DI
protocol EventBusProtocol {
    func emit(_ event: AuthEvent)
    func emit(_ event: PlaybackEvent)
    func emit(_ event: DownloadEvent)

    func authEvents() -> AsyncStream<AuthEvent>
    func playbackEvents() -> AsyncStream<PlaybackEvent>
    func downloadEvents() -> AsyncStream<DownloadEvent>
}

// Uso en ViewModel (solo los que reaccionan a eventos globales: Player, Download)
final class DownloadViewModel: EventBusObservable {
    var eventBus: EventBusProtocol
    private var downloadEventTask: Task<Void, Never>?

    init(downloadUseCases: DownloadUseCases, eventBus: EventBusProtocol) {
        self.eventBus = eventBus
        downloadEventTask = makeEventTask(stream: { $0.downloadEvents() },
                                          handler: { [weak self] in await self?.handleDownloadEvent($0) })
    }
}
```

### ReadStore (lectura reactiva de listas)

Home, Library, Playlist y Search **no** dependen del EventBus para reactividad: cada uno tiene
su propio `ReadStoreProtocol` (ISP — protocolos pequeños por dominio, no uno genérico) cuya
implementación observa `ModelContext.didSave` de SwiftData directamente y emite una señal
`AsyncStream<Void>` cuando cambia algo relevante para ese dominio. El ViewModel simplemente
vuelve a preguntar al mismo `UseCase` (con queries targeted, no `getAll()+filter`).

```swift
// Domain/ReadStores/LibraryReadStoreProtocol.swift
@MainActor
protocol LibraryReadStoreProtocol: AnyObject {
    func allSongs() async throws -> [Song]
    func stats() async throws -> LibraryStats
    func changes() -> AsyncStream<Void>
}

// Uso en ViewModel
init(libraryUseCases: LibraryUseCases, readStore: LibraryReadStoreProtocol) {
    self.libraryUseCases = libraryUseCases
    self.readStore = readStore
    changesTask = Task { [weak self] in
        guard let self else { return }
        for await _ in readStore.changes() {
            await self.loadSongs()
        }
    }
}
```

**Por qué no `@Query` de SwiftUI:** los ViewModels son `@Observable` puros (no Views), así que
`@Query` no aplica. `ModelContextChangeObserver` (`Data/ReadStores/Support/`) hace ese mismo
trabajo a nivel de ViewModel, filtrando por nombre de entidad (`SongDTO`, `PlaylistDTO`) para no
notificar cambios irrelevantes.

### Modulo Auth (Facade + Strategy Pattern)

Modulo simplificado usando **Facade + Strategy** en lugar de Clean Architecture completa:

```
Auth Module (7 archivos)
+-- AuthState.swift           # Estados (unknown, checking, authenticated, unauthenticated)
|                             # AuthUser (modelo unico Codable)
|                             # AuthProvider (apple, google, supabase, restAPI)
|                             # AuthError (errores tipados)
|
+-- AuthStrategy.swift        # Protocol AuthStrategy
|                             # AppleAuthStrategy (Sign In with Apple)
|                             # (Extensible: GoogleStrategy, SupabaseStrategy, etc.)
|
+-- AuthFacade.swift          # Facade principal
|                             # Coordina: Strategy + Storage + EventBus
|                             # API simple: signIn(), signOut(), checkAuth()
|
+-- AuthEnvironment.swift     # AppEnvironment (dev, qa, staging, prod)
|                             # Configuraciones por proveedor
|
+-- AuthStrategyFactory.swift # Factory que crea estrategias segun ambiente
|
+-- AuthViewModel.swift       # ViewModel delgado (@Observable)
|                             # Delega a AuthFacade
|                             # Expone: isAuthenticated, displayName, etc.
|
+-- AuthLoginView.swift       # Vista SwiftUI con SignInWithAppleButton
```

**Ventajas sobre Clean Architecture:**
- 7 archivos vs 12 archivos (42% reduccion)
- Sin mappers (modelo unico AuthUser)
- Sin capas de abstraccion innecesarias
- Extensible via nuevas Strategies

### Concurrencia Swift 6 — Patrones Utilizados

El proyecto compila con cero advertencias en Swift 6 strict concurrency mode. Cada tipo tiene su aislamiento declarado explícitamente:

| Patrón | Donde se usa | Por qué |
|--------|-------------|---------|
| `@MainActor class` | ViewModels, AudioPlayerService, DataSources | Todo el estado de UI y servicios de audio se accede desde el main thread |
| `private actor State` | `MegaDownloadState`, `GoogleDriveDownloadState` | Estado mutable de descargas concurrentes — exclusividad garantizada por el compilador |
| `nonisolated func` | Delegates de AVFoundation, URLSession, NotificationCenter | El sistema llama estos métodos en threads arbitrarios — no pueden ser `@MainActor` |
| `Task { @MainActor [weak self] in }` | Dentro de callbacks `nonisolated` | Puente de regreso al main actor para emitir eventos y actualizar estado |
| `await MainActor.run { }` | Dentro de Tasks en actors | Emitir eventos al EventBus (`@MainActor`) desde contexto de actor |
| `[self]` / `[weak self]` | Todos los Task closures | Swift 6 requiere listas de captura explícitas en todos los closures concurrentes |

```swift
// Ejemplo: NSObject + @MainActor + nonisolated delegates
@MainActor
final class AudioPlayerService: NSObject, AudioPlayerServiceProtocol, AudioPlayerProtocol {

    // ✅ Todos los métodos son @MainActor por defecto
    func play(songID: UUID, url: URL) { ... }

    // ✅ nonisolated para callbacks del sistema (llamados desde threads arbitrarios)
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.eventBus.emit(.songFinished(self.currentlyPlayingID!))
        }
    }
}

// Ejemplo: actor para estado mutable concurrente
private actor MegaDownloadState {
    var activeTasks: [Int: MegaDownloadTaskInfo] = [:]
    // Acceso exclusivo garantizado — sin NSLock, sin data races
    func addTask(_ info: MegaDownloadTaskInfo, for id: Int) { activeTasks[id] = info }
}
```

### Principios SOLID

| Principio | Implementacion |
|-----------|----------------|
| **Single Responsibility** | Cada clase tiene una unica responsabilidad (ViewModel, UseCase, Repository, DataSource) |
| **Open/Closed** | Extension via protocolos sin modificar codigo existente |
| **Liskov Substitution** | Todas las implementaciones son intercambiables via protocolos |
| **Interface Segregation** | Protocolos pequenos y especificos (AudioPlayerProtocol, y los 4 `ReadStoreProtocol` — uno por dominio en vez de uno genérico) |
| **Dependency Inversion** | Todas las dependencias se inyectan via constructor, dependiendo de abstracciones |

## Tecnologias

### Core
- **Swift 6** con concurrencia moderna (async/await)
- **SwiftUI** para UI declarativa
- **SwiftData** para persistencia (@Model)
- **@Observable** macro para estado reactivo

### Audio & Media
- **AVFoundation** y **AVAudioEngine** para reproduccion
- **MediaPlayer** para integracion con sistema
- **ActivityKit** para Live Activities

### Cloud & Storage
- **Google Drive API** para sincronizacion
- **Keychain Services** para almacenamiento seguro

### Concurrencia (Swift 6 Strict Mode — cero advertencias)
- **@MainActor** para aislamiento al main thread en ViewModels y servicios
- **actor** para estado mutable compartido en DataSources (`MegaDownloadState`, `GoogleDriveDownloadState`)
- **Task API** para concurrencia estructurada (reemplaza GCD/DispatchQueue)
- **AsyncStream** para el sistema de eventos reactivo (EventBus)
- **nonisolated** en callbacks de sistema (AVFoundation, URLSession, NotificationCenter)
- `@unchecked Sendable` solo en `ActiveTasksManager` (interno de `DownloadViewModel`, accedido exclusivamente desde `@MainActor`)

## Requisitos

- **iOS 18.0+**
- **Xcode 16.0+** (Swift 6)
- **Proveedor de nube**: Google Drive (API en Cloud Console) **o** MEGA (URL de carpeta pública)
- **Dispositivo físico** recomendado para Live Activities y Dynamic Island

## Instalación

1. Clona el repositorio:
```bash
git clone https://github.com/rapser/sinkmusic.git
cd sinkmusic
```

2. Configura el almacenamiento en la nube:
   - **Google Drive**: API en [Google Cloud Console](https://console.cloud.google.com/) y credenciales en la app
   - **MEGA**: URL de carpeta pública (o escáner QR) en Configuración

3. Abre el proyecto en Xcode
```bash
open sinkmusic.xcodeproj
```

4. Configura el equipo de desarrollo en Signing & Capabilities

5. Compila y ejecuta (Cmd+R)

## Testing

El target `sinkmusicTests` cubre los 7 use cases de la capa de dominio con **mocks en memoria** — sin SwiftData, sin red, sin filesystem. Cada mock implementa el protocolo de repositorio correspondiente y expone contadores/resultados configurables para hacer asserts precisos.

### Estructura

```
sinkmusicTests/
├── Helpers/
│   └── TestFixtures.swift          — Song.make(), Playlist.make(), CloudFile.make()
├── Mocks/
│   ├── MockSongRepository.swift
│   ├── MockPlaylistRepository.swift
│   ├── MockAudioPlayerRepository.swift
│   ├── MockCloudStorageRepository.swift
│   ├── MockCredentialsRepository.swift
│   ├── MockMetadataRepository.swift
│   ├── MockEventBus.swift          — solo Auth/Playback/Download (ya no DataChangeEvent)
│   ├── MockHomeReadStore.swift
│   ├── MockLibraryReadStore.swift
│   ├── MockPlaylistReadStore.swift
│   └── MockSearchReadStore.swift
├── UseCases/
│   ├── PlayerUseCasesTests.swift    — 14 tests
│   ├── LibraryUseCasesTests.swift   — 22 tests
│   ├── PlaylistUseCasesTests.swift  — 26 tests
│   ├── SearchUseCasesTests.swift    — 19 tests
│   ├── DownloadUseCasesTests.swift  — 24 tests
│   ├── EqualizerUseCasesTests.swift — 10 tests
│   └── SettingsUseCasesTests.swift  — 34 tests
├── ViewModels/                      — Home/Library/Playlist/Search migrados a mocks de ReadStore
└── ReadStores/                      — integración real, con ModelContainer en memoria (sin mocks)
    ├── ReadStoreTestSupport.swift   — helpers: makeInMemoryContainer(), insertSong(), insertPlaylist()
    ├── ModelContextChangeObserverTests.swift
    ├── HomeReadStoreTests.swift
    ├── LibraryReadStoreTests.swift
    ├── PlaylistReadStoreTests.swift
    ├── SearchReadStoreTests.swift
    └── ReactiveFlowTests.swift      — 4 flujos end-to-end (descarga, borrado, playlist, búsqueda)
```

> **Nota sobre `ModelContainer` en tests**: `ModelContext` no retiene fuerte a su `ModelContainer`.
> `ReadStoreTestSupport.makeInMemoryContainer()` devuelve el `ModelContainer` (no solo su
> `.mainContext`) — el test debe quedarse con esa referencia (`let container = ...`) durante toda
> su ejecución, o el contexto queda apuntando a memoria liberada.

### Patrón de mocks

Todos los mocks son `@MainActor final class` para cumplir con Swift 6 strict concurrency:

```swift
@MainActor
final class MockSongRepository: SongRepositoryProtocol {
    var songs: [Song] = []
    var createCallCount = 0

    func getAll() async throws -> [Song] { songs }
    func create(_ song: Song) async throws {
        createCallCount += 1
        songs.append(song)
    }
    // ...
}
```

### Patrón de test

Clases de test `@MainActor` con `setUp`/`tearDown` síncronos y métodos `async`:

```swift
@MainActor
final class PlayerUseCasesTests: XCTestCase {
    private var sut: PlayerUseCases!
    private var mockAudioPlayer: MockAudioPlayerRepository!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        sut = PlayerUseCases(audioPlayerRepository: mockAudioPlayer, songRepository: MockSongRepository())
    }

    func test_play_songNotFound_throwsSongNotFound() async {
        do {
            try await sut.play(songID: UUID())
            XCTFail("Expected PlayerError.songNotFound")
        } catch PlayerError.songNotFound { }
    }
}
```

### Ejecutar tests

```
Cmd+U  (Xcode) — corre todos los tests del target sinkmusicTests
```

## Changelog

Para ver el historial completo de cambios, consulta [CHANGELOG.md](./CHANGELOG.md)

## Autor

**Miguel Tomairo (rapser)**
- GitHub: [@rapser](https://github.com/rapser)

## Licencia

Este proyecto es privado y pertenece a **rapser**.
