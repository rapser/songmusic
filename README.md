# 🎵 SinkMusic

Una aplicación de música moderna para iOS con reproducción de audio, gestión de playlists y sincronización con Google Drive.

## ✨ Características

- 🎵 Reproducción de audio con ecualizador de 10 bandas
- 📥 Descarga de canciones desde Google Drive
- 🎨 Extracción automática de metadatos y artwork
- 📋 Gestión de playlists personalizadas
- 🔀 Modo aleatorio y repetición
- 🎚️ Ecualizador personalizable con presets
- 💾 Almacenamiento local con SwiftData

## 🏗️ Arquitectura

Este proyecto implementa **Clean Architecture + MVVM** siguiendo los principios **SOLID**.

Consulta [ARCHITECTURE.md](./ARCHITECTURE.md) para más detalles sobre la arquitectura.

### Capas Principales

- **Presentation**: Views y ViewModels (SwiftUI + Combine)
- **Domain**: UseCases y Protocolos (lógica de negocio)
- **Data**: Repositories y Services (acceso a datos)

## 🎯 Principios SOLID

- ✅ **Single Responsibility**: Cada clase tiene una única responsabilidad
- ✅ **Open/Closed**: Abierto a extensión, cerrado a modificación
- ✅ **Liskov Substitution**: Las abstracciones son intercambiables
- ✅ **Interface Segregation**: Interfaces específicas y focalizadas
- ✅ **Dependency Inversion**: Dependencias de abstracciones, no implementaciones

## 🚀 Empezar

### Requisitos

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

### Instalación

1. Clona el repositorio
```bash
git clone https://github.com/rapser/songmusic.git
cd songmusic
```

2. Abre el proyecto en Xcode
```bash
open sinkmusic.xcodeproj
```

3. Compila y ejecuta (⌘R)

## 📱 Uso

### Configuración Inicial

1. Abre la app
2. Ve a **Configuración** (⚙️)
3. Sincroniza la biblioteca con Google Drive
4. Descarga tus canciones favoritas

### Reproducir Música

1. Ve a **Inicio** para ver tus canciones descargadas
2. Toca una canción para reproducirla
3. Usa el player para controlar la reproducción

### Crear Playlists

1. Ve a **Playlists** (📋)
2. Toca el botón **+** para crear una nueva playlist
3. Agrega canciones desde cualquier vista con el menú contextual

### Personalizar Ecualizador

1. Toca el botón de ecualizador en el player
2. Ajusta las bandas manualmente o selecciona un preset
3. Los cambios se aplican en tiempo real

## 🛠️ Tecnologías

- **SwiftUI**: Framework de UI declarativo
- **Combine**: Programación reactiva
- **SwiftData**: Persistencia de datos
- **AVFoundation**: Reproducción de audio
- **AVAudioEngine**: Procesamiento de audio y efectos

## 📂 Estructura del Proyecto

```
sinkmusic/
├── Core/
│   ├── Protocols/          # Interfaces (DIP)
│   ├── Errors/             # Manejo de errores
│   └── DependencyContainer # IoC Container
├── Domain/
│   └── UseCases/           # Lógica de negocio
├── Data/
│   └── Repositories/       # Acceso a datos
├── Model/                  # Modelos de dominio
├── Services/               # Servicios técnicos
├── ViewModel/              # Lógica de presentación
├── View/                   # Interfaz de usuario
└── Utils/                  # Utilidades
```

## 🧪 Testing

Para ejecutar tests:

```bash
⌘U en Xcode
```

La arquitectura facilita testing con inyección de dependencias:

```swift
// Ejemplo de test con mocks
let mockPlayer = MockAudioPlayer()
let viewModel = RefactoredPlayerViewModel(
    audioPlayer: mockPlayer,
    downloadService: mockDownloadService,
    metadataService: mockMetadataService,
    songRepository: mockRepository
)
```

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

### Lineamientos de Contribución

- Seguir principios SOLID
- Mantener la arquitectura limpia
- Escribir tests para nueva funcionalidad
- Documentar cambios importantes

## 📄 Licencia

Este proyecto es privado y pertenece a [rapser].

## 👤 Autor

**rapser**
- GitHub: [@rapser](https://github.com/rapser)

## 🙏 Agradecimientos

- Clean Architecture por Uncle Bob
- Comunidad de Swift/iOS
- Contribuidores del proyecto

## 📝 Changelog

### v2.0.0 - Refactor Arquitectónico (2025-11-20)
- ✅ Implementación completa de Clean Architecture
- ✅ Aplicación de principios SOLID
- ✅ Patrón Repository para acceso a datos
- ✅ UseCases para lógica de negocio
- ✅ Dependency Injection Container
- ✅ Mejora en manejo de errores
- ✅ Documentación completa de arquitectura

### v1.0.0 - Versión Inicial
- 🎵 Reproducción de audio básica
- 📥 Descarga de canciones
- 📋 Gestión de playlists
- 🎚️ Ecualizador básico

## 📞 Soporte

Si encuentras algún problema o tienes sugerencias:

1. Abre un [Issue](https://github.com/rapser/songmusic/issues)
2. Describe el problema detalladamente
3. Incluye pasos para reproducir (si aplica)

---

Hecho con ❤️ y Swift
