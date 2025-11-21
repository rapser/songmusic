# SinkMusic - Arquitectura Refactorizada

## 📐 Arquitectura

Este proyecto implementa una arquitectura **Clean Architecture + MVVM** siguiendo los principios **SOLID**.

### Estructura de Capas

```
┌─────────────────────────────────────┐
│       Presentation Layer            │
│  (Views + ViewModels)               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Domain Layer                  │
│  (UseCases + Protocols)             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Data Layer                    │
│  (Repositories + Services)          │
└─────────────────────────────────────┘
```

## 🎯 Principios SOLID Implementados

### 1. **Single Responsibility Principle (SRP)**
Cada clase tiene una única responsabilidad:

- **AudioEngineManager**: Solo gestiona el motor de audio y sus nodos
- **PlaybackStateManager**: Solo gestiona el estado de reproducción
- **SongRepository**: Solo accede a datos de canciones
- **PlaylistRepository**: Solo accede a datos de playlists
- **UseCases**: Cada UseCase orquesta una operación específica

### 2. **Open/Closed Principle (OCP)**
Las clases están abiertas a extensión pero cerradas a modificación:

- Los servicios implementan protocolos, permitiendo nuevas implementaciones sin modificar código existente
- Los UseCases pueden extenderse sin modificar los ViewModels

### 3. **Liskov Substitution Principle (LSP)**
Las implementaciones concretas pueden sustituirse por sus abstracciones:

- `AudioPlayerService` puede reemplazarse por cualquier implementación de `AudioPlayerProtocol`
- `DownloadService` puede reemplazarse por cualquier implementación de `DownloadServiceProtocol`

### 4. **Interface Segregation Principle (ISP)**
Interfaces específicas en lugar de interfaces generales:

- `AudioPlayerProtocol`: Solo métodos de reproducción
- `DownloadServiceProtocol`: Solo métodos de descarga
- `MetadataServiceProtocol`: Solo métodos de metadatos
- `SongRepositoryProtocol` y `PlaylistRepositoryProtocol`: Operaciones específicas

### 5. **Dependency Inversion Principle (DIP)**
Dependencias de abstracciones, no de implementaciones concretas:

- ViewModels dependen de protocolos, no de clases concretas
- UseCases dependen de protocolos
- `DependencyContainer` gestiona la creación de dependencias

## 📁 Estructura de Archivos

```
sinkmusic/
├── Core/
│   ├── Protocols/
│   │   ├── AudioPlayerProtocol.swift
│   │   ├── DownloadServiceProtocol.swift
│   │   ├── MetadataServiceProtocol.swift
│   │   ├── GoogleDriveServiceProtocol.swift
│   │   └── RepositoryProtocols.swift
│   ├── Errors/
│   │   └── AppError.swift
│   └── DependencyContainer.swift
├── Domain/
│   ├── UseCases/
│   │   ├── DownloadSongUseCase.swift
│   │   ├── DeleteSongUseCase.swift
│   │   ├── PlaySongUseCase.swift
│   │   ├── SyncLibraryUseCase.swift
│   │   └── ManagePlaylistUseCase.swift
├── Data/
│   ├── Repositories/
│   │   ├── SongRepository.swift
│   │   └── PlaylistRepository.swift
├── Model/
│   ├── Song.swift
│   └── Playlist.swift
├── Services/
│   ├── RefactoredAudioPlayerService.swift
│   ├── AudioEngineManager.swift
│   ├── PlaybackStateManager.swift
│   ├── DownloadService.swift
│   ├── MetadataService.swift
│   └── GoogleDriveService.swift
├── ViewModel/
│   ├── RefactoredMainViewModel.swift
│   ├── RefactoredPlayerViewModel.swift
│   ├── RefactoredSongListViewModel.swift
│   └── RefactoredPlaylistViewModel.swift
└── View/
    └── (Views existentes)
```

## 🔄 Flujo de Datos

### Ejemplo: Descargar una Canción

```
View
  ↓ (user action)
ViewModel.download(song)
  ↓ (calls)
DownloadSongUseCase.execute(song)
  ↓ (coordinates)
DownloadService.download() → MetadataService.extract() → SongRepository.save()
  ↓ (updates)
ViewModel @Published properties
  ↓ (updates)
View (SwiftUI auto-update)
```

## 🧩 Componentes Principales

### UseCases (Lógica de Negocio)

- **DownloadSongUseCase**: Orquesta descarga + extracción de metadatos + guardado
- **PlaySongUseCase**: Valida y ejecuta reproducción de canciones
- **SyncLibraryUseCase**: Sincroniza biblioteca con Google Drive
- **ManagePlaylistUseCase**: Gestiona operaciones CRUD de playlists

### Repositories (Acceso a Datos)

- **SongRepository**: Abstrae acceso a SwiftData para canciones
- **PlaylistRepository**: Abstrae acceso a SwiftData para playlists

### Services (Servicios Técnicos)

- **RefactoredAudioPlayerService**: Servicio de reproducción (implementa protocolo)
- **DownloadService**: Servicio de descargas HTTP
- **MetadataService**: Extracción de metadatos de audio
- **GoogleDriveService**: Integración con Google Drive API

### ViewModels (Presentación)

- **RefactoredMainViewModel**: ViewModel principal de la app
- **RefactoredPlayerViewModel**: Controla el reproductor
- **RefactoredSongListViewModel**: Gestiona lista de canciones
- **RefactoredPlaylistViewModel**: Gestiona playlists

## 🔧 Dependency Injection

El proyecto usa un **DependencyContainer** para gestionar dependencias:

```swift
// Uso en SwiftUI
@StateObject private var mainViewModel = DependencyContainer.shared.makeMainViewModel(modelContext: modelContext)
```

### Ventajas:

1. **Testability**: Fácil inyectar mocks en tests
2. **Mantenibilidad**: Cambios centralizados
3. **Flexibilidad**: Cambiar implementaciones sin modificar consumidores

## 🧪 Testing

La arquitectura facilita testing:

```swift
// Mock del servicio de audio
class MockAudioPlayer: AudioPlayerProtocol {
    // Implementación mock
}

// Inyectar en ViewModel para testing
let viewModel = RefactoredPlayerViewModel(
    audioPlayer: MockAudioPlayer(),
    downloadService: MockDownloadService(),
    metadataService: MockMetadataService(),
    songRepository: MockSongRepository()
)
```

## ✅ Mejoras Implementadas

### Antes del Refactor:
- ❌ ViewModels con múltiples responsabilidades
- ❌ Dependencias directas de clases concretas
- ❌ Lógica de negocio mezclada con presentación
- ❌ Sin manejo estructurado de errores
- ❌ Difícil de testear

### Después del Refactor:
- ✅ Separación clara de responsabilidades (SRP)
- ✅ Dependency Injection con protocolos (DIP)
- ✅ UseCases para lógica de negocio
- ✅ Repository Pattern para acceso a datos
- ✅ Manejo estructurado de errores con tipos personalizados
- ✅ Fácilmente testeable con mocks
- ✅ Escalable y mantenible

## 📝 Buenas Prácticas Aplicadas

1. **Naming Conventions**: Nombres descriptivos y claros
2. **Documentation**: Comentarios explicando responsabilidades
3. **Error Handling**: Tipos de error específicos por dominio
4. **Async/Await**: Uso correcto de concurrencia moderna
5. **Protocols**: Abstracciones bien definidas
6. **Immutability**: Uso de `let` donde sea posible
7. **Access Control**: `private`, `final` para encapsulación

## 🚀 Cómo Extender

### Agregar un nuevo servicio:

1. Crear protocolo en `Core/Protocols/`
2. Implementar servicio en `Services/`
3. Registrar en `DependencyContainer`
4. Usar en UseCases/ViewModels vía protocolo

### Agregar un nuevo UseCase:

1. Crear en `Domain/UseCases/`
2. Inyectar dependencias necesarias (protocolos)
3. Implementar método `execute()`
4. Usar desde ViewModel

## 📚 Recursos

- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [MVVM Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)

## 👥 Mantenimiento

Para mantener la calidad del código:

1. Seguir principios SOLID en nuevas features
2. Mantener ViewModels delgados (usar UseCases)
3. No saltar capas (View → ViewModel → UseCase → Repository/Service)
4. Escribir tests unitarios para UseCases
5. Documentar decisiones arquitectónicas importantes
