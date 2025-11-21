import Foundation
import SwiftData

// Script temporal para limpiar el caché de colores
// Ejecutar una vez y luego eliminar este archivo

@MainActor
func clearColorCache() {
    let modelContainer: ModelContainer
    
    do {
        modelContainer = try ModelContainer(for: Song.self, Playlist.self)
    } catch {
        print("Error al crear el contenedor: \(error)")
        return
    }
    
    let context = modelContainer.mainContext
    
    do {
        let descriptor = FetchDescriptor<Song>()
        let songs = try context.fetch(descriptor)
        
        print("Limpiando caché de colores para \(songs.count) canciones...")
        
        for song in songs {
            song.cachedDominantColorRed = nil
            song.cachedDominantColorGreen = nil
            song.cachedDominantColorBlue = nil
        }
        
        try context.save()
        print("✅ Caché de colores limpiado exitosamente")
    } catch {
        print("❌ Error al limpiar caché: \(error)")
    }
}
