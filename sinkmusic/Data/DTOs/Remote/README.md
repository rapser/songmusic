# Remote DTOs

Esta carpeta contiene DTOs (Data Transfer Objects) para fuentes de datos remotas.

## Propósito

Los DTOs remotos representan la estructura de datos que viene de servicios externos:
- APIs REST (Supabase, Firebase, etc.)
- Cloud Storage (Google Drive, OneDrive, Mega, etc.)
- Servicios de terceros

## Ejemplos futuros

```swift
// CloudFileDTO.swift - Para archivos de Google Drive, OneDrive, etc.
struct CloudFileDTO: Codable {
    let id: String
    let name: String
    let size: Int64
    let mimeType: String
    let downloadURL: String?
}

// SupabaseUserDTO.swift - Para usuarios de Supabase
struct SupabaseUserDTO: Codable {
    let id: String
    let email: String
    let created_at: String
}

// SupabaseSongDTO.swift - Para canciones sincronizadas con Supabase
struct SupabaseSongDTO: Codable {
    let id: String
    let title: String
    let artist: String
    let cloudFileId: String?
}
```

## Flujo de datos

```
Remote API → RemoteDTO → Mapper → Entity (Domain)
```

Por ejemplo:
```
Google Drive API → CloudFileDTO → CloudFileMapper → CloudFileEntity
```
