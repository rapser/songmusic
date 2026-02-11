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

### CarPlay
- Integracion nativa con CarPlay
- Navegacion por biblioteca y playlists desde el auto
- Controles de reproduccion seguros mientras conduces

### Live Activities & Dynamic Island
- Reproductor en vivo con Dynamic Island (iPhone 14 Pro+)
- Controles de reproduccion desde Lock Screen
- Artwork y metadatos en tiempo real

### Almacenamiento en la nube (Google Drive / MEGA)
- **Dos proveedores**: Google Drive o MEGA (selección en Configuración)
- Sincronización automática con la carpeta configurada
- **Descarga individual** por canción y **Descargar todo** (solo con MEGA)
- Cola de descargas secuencial con límites por proveedor (Swift 6: actor + async/await)
- Aviso al usuario cuando se alcanza el límite de MEGA (5 GB/día) y limpieza de estado
- Extracción automática de metadatos (ID3, artwork); escritura atómica del archivo para evitar errores de formato
- Gestión de caché de imágenes (3 tamaños: 32×32, 64×64, full)

### Playlists
- Creacion y gestion de playlists personalizadas
- Agregar/remover canciones con gestos intuitivos
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

### Búsqueda
- Búsqueda en tiempo real con debouncing (300 ms)
- Filtrado por título, artista y álbum
- Resultados instantáneos

## Arquitectura

Este proyecto implementa **Clean Architecture + MVVM** con **Dependency Injection pura** siguiendo los principios **SOLID** y usando **Swift 6** con **strict concurrency** verificada por el compilador (cero `@unchecked Sendable`, cero `NSLock`, cero `DispatchQueue`).

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
|   +-- CarPlaySceneDelegate.swift  # Delegado de CarPlay
|
+-- Core/                           # Utilidades compartidas
|   +-- Errors/                     # Errores de dominio
|   |   +-- AppError.swift
|   |   +-- SyncError.swift
|   +-- EventBus/                   # Sistema de eventos reactivo
|   |   +-- EventBus.swift          # Implementacion
|   |   +-- EventBusProtocol.swift  # Abstraccion
|   |   +-- Events/
|   |       +-- AuthEvent.swift
|   |       +-- DataChangeEvent.swift
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
|   |   |   +-- SwiftDataNotificationService.swift
|   |   +-- Remote/
|   |   |   +-- GoogleDriveDataSource.swift
|   |   +-- Protocols/
|   |       +-- GoogleDriveServiceProtocol.swift
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
|   |   +-- CarPlayServiceProtocol.swift
|   |   +-- KeychainServiceProtocol.swift
|   |   +-- LiveActivityServiceProtocol.swift
|   +-- Services/                   # Implementaciones
|       +-- AudioPlayerService.swift
|       +-- CarPlayService.swift
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

```
+-------+     +----------+     +----------+     +------------+     +------------+
| View  | --> | ViewModel| --> | UseCase  | --> | Repository | --> | DataSource |
+-------+     +----------+     +----------+     +------------+     +------------+
    ^              |                                                      |
    |              |                                                      |
    +--------------+------------------------------------------------------+
                   |              EventBus (Eventos reactivos)            |
                   +------------------------------------------------------+
```

1. **View** llama accion en **ViewModel**
2. **ViewModel** ejecuta **UseCase**
3. **UseCase** coordina **Repositories**
4. **Repository** accede a **DataSources** (Local/Remote)
5. **DataSource** emite eventos via **EventBus**
6. **ViewModel** escucha eventos y actualiza estado
7. **View** se re-renderiza automaticamente

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
    var carPlayService: CarPlayServiceProtocol

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

### EventBus (Sistema de Eventos)

Comunicacion reactiva entre capas sin acoplar componentes:

```swift
// Protocolo para DI
protocol EventBusProtocol {
    func emit(_ event: DataChangeEvent)
    func emit(_ event: AuthEvent)
    func emit(_ event: PlaybackEvent)
    func emit(_ event: DownloadEvent)

    func dataEvents() -> AsyncStream<DataChangeEvent>
    func authEvents() -> AsyncStream<AuthEvent>
    func playbackEvents() -> AsyncStream<PlaybackEvent>
    func downloadEvents() -> AsyncStream<DownloadEvent>
}

// Uso en ViewModel
init(useCases: UseCases, eventBus: EventBusProtocol) {
    self.eventBus = eventBus

    Task {
        for await event in eventBus.dataEvents() {
            handleEvent(event)
        }
    }
}
```

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
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {

    // ✅ Todos los métodos son @MainActor por defecto
    func play(songID: UUID, url: URL) { ... }

    // ✅ nonisolated para callbacks del sistema (llamados desde threads arbitrarios)
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool) {
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
| **Interface Segregation** | Protocolos pequenos y especificos (EventBusProtocol, AudioPlayerProtocol) |
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
- **CarPlay Framework** para vehiculos
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
- Sin `@unchecked Sendable` — toda la seguridad de concurrencia es verificada por el compilador

## Requisitos

- **iOS 18.0+**
- **Xcode 16.0+** (Swift 6)
- **Proveedor de nube**: Google Drive (API en Cloud Console) **o** MEGA (URL de carpeta pública)
- **Dispositivo físico** recomendado para CarPlay y Live Activities

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

La arquitectura con DI facilita el testing:

```swift
// Mock de EventBus
class MockEventBus: EventBusProtocol {
    var emittedEvents: [DataChangeEvent] = []

    func emit(_ event: DataChangeEvent) {
        emittedEvents.append(event)
    }
}

// Test de ViewModel
func testViewModel() {
    let mockEventBus = MockEventBus()
    let mockUseCases = MockUseCases()
    let viewModel = PlayerViewModel(
        playerUseCases: mockUseCases,
        eventBus: mockEventBus
    )

    viewModel.play()

    XCTAssertTrue(mockUseCases.playCalled)
}
```

## Changelog

Para ver el historial completo de cambios, consulta [CHANGELOG.md](./CHANGELOG.md)

## Autor

**Miguel Tomairo (rapser)**
- GitHub: [@rapser](https://github.com/rapser)

## Licencia

Este proyecto es privado y pertenece a **rapser**.
