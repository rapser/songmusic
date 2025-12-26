# 🎵 SinkMusic

Una aplicación de música moderna para iOS con reproducción de audio de alta calidad, gestión de playlists, integración con CarPlay y sincronización con Google Drive.

## ✨ Características

### 🎵 Reproducción de Audio
- Reproducción con AVAudioEngine y ecualizador de 6 bandas
- Controles de reproducción avanzados (play/pause, siguiente, anterior)
- Modo aleatorio y tres modos de repetición (off, all, one)
- Soporte para reproducción en background
- Integración con Lock Screen y Control Center
- Continuación automática después de llamadas telefónicas
- Pausa automática al desconectar auriculares

### 🚗 CarPlay
- Integración nativa con CarPlay
- Navegación por biblioteca y playlists desde el auto
- Controles de reproducción seguros mientras conduces

### 📱 Live Activities & Dynamic Island
- Reproductor en vivo con Dynamic Island (iPhone 14 Pro+)
- Controles de reproducción desde Lock Screen
- Artwork y metadatos en tiempo real

### 📥 Google Drive
- Sincronización automática con carpeta de Google Drive
- Descarga de canciones para reproducción offline
- Extracción automática de metadatos (ID3, artwork)
- Gestión de caché de imágenes (3 tamaños: 32x32, 64x64, full)

### 📋 Playlists
- Creación y gestión de playlists personalizadas
- Agregar/remover canciones con gestos intuitivos
- Contador de reproducciones y últimas canciones reproducidas
- Grid view estilo Spotify con top songs carousel

### 🎚️ Ecualizador
- 6 bandas ajustables (60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 15kHz)
- Presets predefinidos (Rock, Pop, Jazz, Clásica, etc.)
- Aplicación en tiempo real sin interrumpir reproducción

### 🔍 Búsqueda
- Búsqueda en tiempo real con debouncing (300ms)
- Filtrado por título, artista y álbum
- Resultados instantáneos

## 🏗️ Arquitectura

Este proyecto implementa **MVVM + Protocol-Oriented Programming** siguiendo los principios **SOLID** y usando **Swift 6** con concurrencia moderna.

### Arquitectura Modular

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  ┌─────────────┐      ┌──────────────┐ │
│  │   Views     │◄─────┤  ViewModels  │ │
│  │  (SwiftUI)  │      │ (@MainActor) │ │
│  └─────────────┘      └──────┬───────┘ │
└────────────────────────────┬─┬──────────┘
                             │ │
                ┌────────────┘ └─────────────┐
                │                             │
┌───────────────▼──────┐      ┌──────────────▼────┐
│   Service Layer      │      │   Data Layer      │
│  ┌────────────────┐  │      │  ┌─────────────┐  │
│  │   Services     │  │      │  │   Models    │  │
│  │  (Protocols)   │  │      │  │ (@Model)    │  │
│  └────────────────┘  │      │  └─────────────┘  │
└──────────────────────┘      └───────────────────┘
```

### Capas Principales

#### Presentation Layer
- **Views**: Componentes SwiftUI declarativos y reutilizables
- **ViewModels**: Lógica de presentación con `@MainActor` para thread-safety
  - `PlayerViewModel`: Reproducción de audio
  - `LibraryViewModel`: Gestión de biblioteca
  - `PlaylistViewModel`: Gestión de playlists
  - `EqualizerViewModel`: Control de ecualizador
  - `MetadataCacheViewModel`: Caché de artwork

#### Service Layer
- **AudioPlayerService**: Reproducción con AVAudioEngine
- **GoogleDriveService**: Sincronización y descarga
- **MetadataService**: Extracción de ID3 tags
- **CarPlayService**: Integración con CarPlay
- **LiveActivityService**: Dynamic Island y Live Activities
- **KeychainService**: Almacenamiento seguro de credenciales

#### Data Layer
- **SwiftData Models**: Persistencia moderna
  - `Song`: Modelo de canción con metadatos
  - `Playlist`: Modelo de playlist con relaciones

### Principios de Diseño

#### Protocol-Oriented Programming
```swift
// Segregación de interfaces - cada protocolo tiene una responsabilidad
protocol AudioPlaybackProtocol {
    func play(songID: UUID, url: URL)
    func pause()
    func seek(to time: TimeInterval)
}

protocol AudioEqualizerProtocol {
    func updateEqualizer(bands: [Float])
}

// Composición de protocolos
protocol AudioPlayerProtocol: AudioPlaybackProtocol,
                              AudioEqualizerProtocol,
                              RemoteControlsProtocol { }
```

#### Dependency Inversion
```swift
// ViewModels dependen de protocolos, no implementaciones concretas
@MainActor
class PlayerViewModel: ObservableObject {
    private var audioPlayerService: AudioPlayerProtocol  // ✅ Protocol

    init(audioPlayerService: AudioPlayerProtocol = AudioPlayerService()) {
        self.audioPlayerService = audioPlayerService
    }
}
```

## 🎯 Principios SOLID

### ✅ Single Responsibility
Cada clase tiene una única responsabilidad bien definida:
- `PlayerViewModel`: Solo maneja estado de reproducción
- `AudioPlayerService`: Solo maneja audio engine
- `MetadataService`: Solo extrae metadatos

### ✅ Open/Closed
Extensible vía protocolos sin modificar código existente:
```swift
protocol AudioPlayerProtocol {
    // Nuevas funcionalidades se agregan aquí
}
```

### ✅ Liskov Substitution
Todas las implementaciones de protocolos son intercambiables:
```swift
let player: AudioPlayerProtocol = AudioPlayerService()  // Intercambiable
```

### ✅ Interface Segregation ⭐
Interfaces pequeñas y específicas:
- `AudioPlaybackProtocol`: Solo reproducción
- `AudioEqualizerProtocol`: Solo ecualizador
- Compuestas en `AudioPlayerProtocol`

### ✅ Dependency Inversion
ViewModels y Services dependen de abstracciones (protocolos), no de clases concretas.

## 🚀 Tecnologías y Frameworks

### Core Technologies
- **Swift 6**: Lenguaje moderno con concurrencia nativa
- **SwiftUI**: Framework declarativo de UI
- **SwiftData**: Persistencia moderna (reemplazo de CoreData)
- **async/await**: Concurrencia moderna (sin Combine)

### Audio & Media
- **AVFoundation**: Reproducción de audio
- **AVAudioEngine**: Procesamiento de audio y efectos
- **MediaPlayer**: Integración con sistema (Now Playing, Remote Commands)
- **CarPlay Framework**: Integración con vehículos

### Cloud & Storage
- **Google Drive API**: Sincronización de música
- **Keychain Services**: Almacenamiento seguro de tokens
- **FileManager**: Gestión de archivos locales

### UI & UX
- **ActivityKit**: Live Activities y Dynamic Island
- **UIKit Integration**: Para componentes específicos (feedback háptico)

### Concurrency & Performance
- **@MainActor**: Thread-safety automático para UI
- **Task API**: Concurrencia estructurada
- **NSLock**: Sincronización de recursos compartidos
- **RunLoop.common**: Timers que funcionan en background

## 📂 Estructura del Proyecto

```
sinkmusic/
├── Application/
│   └── sinkmusicApp.swift          # Entry point
├── Core/
│   ├── Protocols/                  # Definiciones de interfaces
│   │   ├── AudioPlayerProtocol.swift
│   │   └── GoogleDriveServiceProtocol.swift
│   └── Extensions/                 # Extensiones de tipos
│       └── Color+Extension.swift
├── Model/                          # SwiftData Models
│   ├── Song.swift                  # @Model con metadatos
│   └── Playlist.swift              # @Model con relaciones
├── Services/                       # Capa de servicios
│   ├── AudioPlayerService.swift    # AVAudioEngine
│   ├── GoogleDriveService.swift    # API de Google Drive
│   ├── MetadataService.swift       # Extracción ID3
│   ├── CarPlayService.swift        # Integración CarPlay
│   ├── LiveActivityService.swift   # Dynamic Island
│   └── KeychainService.swift       # Almacenamiento seguro
├── ViewModel/                      # Lógica de presentación
│   ├── PlayerViewModel.swift       # @MainActor
│   ├── LibraryViewModel.swift      # @MainActor
│   ├── PlaylistViewModel.swift     # @MainActor
│   ├── EqualizerViewModel.swift    # @MainActor
│   └── MetadataCacheViewModel.swift # @MainActor
├── View/                           # UI SwiftUI
│   ├── Main/
│   │   └── MainAppView.swift       # Tab navigation
│   ├── Home/
│   │   └── HomeView.swift          # Grid + Carousel
│   ├── Player/
│   │   ├── PlayerView.swift        # Full player
│   │   └── MiniPlayerView.swift    # Mini player
│   ├── Playlist/
│   │   └── PlaylistView.swift      # Lista de playlists
│   ├── Settings/
│   │   └── SettingsView.swift      # Configuración
│   └── Components/                 # Componentes reutilizables
├── Utils/                          # Utilidades
│   ├── PreviewData.swift           # Datos para previews
│   └── ImageCompressionService.swift
└── Resources/
    └── Info.plist                  # Configuración del app
```

## 🚀 Empezar

### Requisitos

- **iOS 17.0+** (requerido para Live Activities)
- **Xcode 16.0+** (Swift 6)
- **Cuenta de Google Drive** con API habilitada
- **Dispositivo físico** (para CarPlay y Live Activities)

### Instalación

1. **Clona el repositorio**
```bash
git clone https://github.com/rapser/sinkmusic.git
cd sinkmusic
```

2. **Configurar Google Drive API**
   - Crea un proyecto en [Google Cloud Console](https://console.cloud.google.com/)
   - Habilita Google Drive API
   - Crea credenciales OAuth 2.0
   - Agrega el Client ID al proyecto

3. **Abre el proyecto en Xcode**
```bash
open sinkmusic.xcodeproj
```

4. **Configura el equipo de desarrollo**
   - Selecciona tu equipo en Signing & Capabilities
   - Habilita Push Notifications para Live Activities

5. **Compila y ejecuta** (⌘R)

### Configuración Inicial

1. **Autenticación**
   - Inicia sesión con Sign in with Apple
   - Autoriza acceso a Google Drive

2. **Sincronización**
   - Ve a Settings → Configurar Google Drive
   - Selecciona la carpeta con tus archivos MP3
   - Espera la sincronización inicial

3. **Descarga música**
   - Ve a Settings → Descargar música
   - Selecciona las canciones que deseas offline
   - Los metadatos se extraen automáticamente

## 📱 Uso

### Reproducción

- **Play/Pause**: Toca el botón central
- **Siguiente/Anterior**: Botones de navegación
- **Seek**: Desliza la barra de progreso
- **Shuffle**: Activa/desactiva modo aleatorio
- **Repeat**: Cicla entre Off → All → One

### Ecualizador

1. Toca el ícono de ecualizador en el player
2. Ajusta las 6 bandas manualmente
3. O selecciona un preset (Rock, Pop, Jazz, etc.)
4. Los cambios se aplican en tiempo real

### Playlists

- **Crear**: Botón + en la vista de Playlists
- **Agregar canciones**: Long press en cualquier canción
- **Remover**: Swipe left en la lista de canciones
- **Reproducir**: Toca cualquier canción de la playlist

### CarPlay

- Conecta tu iPhone al auto
- Navega por Biblioteca o Playlists
- Usa controles de volante/pantalla

## 🧪 Testing

```bash
# Ejecutar todos los tests
⌘U en Xcode

# Ejecutar tests específicos
⌘ + Click en el test y seleccionar "Run"
```

La arquitectura con inyección de dependencias facilita testing:

```swift
// Mock de AudioPlayerService
class MockAudioPlayerService: AudioPlayerProtocol {
    var playCallCount = 0

    func play(songID: UUID, url: URL) {
        playCallCount += 1
    }
}

// Test de PlayerViewModel
func testPlaySong() {
    let mockPlayer = MockAudioPlayerService()
    let viewModel = PlayerViewModel(audioPlayerService: mockPlayer)

    viewModel.playSong(song)

    XCTAssertEqual(mockPlayer.playCallCount, 1)
}
```

## 🔧 Optimizaciones de Performance

### Memory Management
- ✅ Todos los closures usan `[weak self]`
- ✅ URLSession delegates se invalidan en deinit
- ✅ Timers se cancelan apropiadamente
- ✅ Tasks se cancelan con deinit

### UI Performance
- ✅ Throttling de `playbackTime` (0.5s) para evitar re-renders
- ✅ SettingsView optimizado con valores cacheados
- ✅ Dictionary lookup O(1) en lugar de O(n)
- ✅ Artwork en 3 tamaños cacheados
- ✅ Color dominante pre-calculado y persistido

### Audio Performance
- ✅ Timer con `RunLoop.common` para background
- ✅ Buffer duration optimizado (5ms)
- ✅ Sample rate preferido (44.1kHz)
- ✅ Manejo de interrupciones (llamadas, alarmas)

## 📝 Changelog

Para ver el historial completo de cambios y versiones, consulta [CHANGELOG.md](./CHANGELOG.md)

### Última Versión: v3.0.0 (2025-12-25) 🎄

**Destacados:**
- ✨ Live Activities & Dynamic Island
- 🚗 CarPlay Integration
- 📊 PlayCount Tracking
- ⚡ Migración completa a Swift 6
- 🐛 6 Memory leaks corregidos
- 🗑️ 11 archivos eliminados (1,242 líneas)
- 🏆 Calificación: A- con SOLID ⭐⭐⭐⭐⭐

## 🤝 Contribuir

### Lineamientos

1. **Código**
   - Seguir principios SOLID
   - Usar Swift 6 moderno (async/await, @MainActor)
   - Evitar force unwraps (!)
   - Usar guard/if-let para optionals

2. **Arquitectura**
   - Mantener separación de capas
   - ViewModels con `@MainActor`
   - Services con protocolos
   - Dependency injection

3. **Performance**
   - Usar `[weak self]` en closures
   - Cancelar Tasks en deinit
   - Cachear valores costosos
   - Evitar re-renders innecesarios

4. **Testing**
   - Escribir tests para nueva funcionalidad
   - Usar mocks para dependencias
   - Test coverage > 70%

### Proceso

1. Fork el proyecto
2. Crea una rama (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto es privado y pertenece a **rapser**.

## 👤 Autor

**Miguel Tomairo (rapser)**
- GitHub: [@rapser](https://github.com/rapser)
- Email: [tu-email]

## 🙏 Agradecimientos

- **Clean Architecture** por Uncle Bob Martin
- **Swift Community** por el soporte y recursos
- **Apple** por los excelentes frameworks
- **Claude** por asistencia en arquitectura y optimización

## 📞 Soporte

¿Encontraste un bug o tienes una sugerencia?

1. Abre un [Issue](https://github.com/rapser/sinkmusic/issues)
2. Describe el problema detalladamente
3. Incluye:
   - iOS version
   - Xcode version
   - Pasos para reproducir
   - Screenshots/logs si aplica

---

**Hecho con ❤️, Swift 6 y mucha música** 🎵
