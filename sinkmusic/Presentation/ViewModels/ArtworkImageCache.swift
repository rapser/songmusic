//
//  ArtworkImageCache.swift
//  sinkmusic
//
//  Presentation Layer - caché visual
//

import Foundation
import UIKit

/// Carátulas nítidas para las celdas grandes, decodificadas al tamaño en que se ven.
///
/// Las listas llevan el thumbnail de 64 px dentro de cada `SongUI` —barato de cargar y de
/// comparar en los diffs—, y eso vale para una fila de 56 pt. Pero la tarjeta de "lo que más
/// escuchas" mide 150×155 pt, que en pantalla @3x son unos 465 px: el thumbnail se ampliaba
/// siete veces y se veía borroso.
///
/// Subir el thumbnail persistido no es la solución: viaja en cada `SongUI`, así que el coste
/// lo pagaría toda la biblioteca para que lo aprovechen diez tarjetas. En su lugar, estas
/// pocas celdas piden la carátula completa y se decodifica al tamaño que necesitan, fuera
/// del main actor. Es el mismo patrón que ya usa el reproductor grande
/// (`MetadataCacheViewModel` + `ArtworkDecoder`): thumbnail al instante, imagen nítida
/// en cuanto está.
@MainActor
@Observable
final class ArtworkImageCache {

    /// Lado máximo para la tarjeta de Inicio: 150×155 pt a @3x caben en 480 px.
    static let cardMaxPixelSize = 480

    @ObservationIgnored
    private let libraryUseCases: LibraryUseCases

    /// `NSCache` y no un diccionario: suelta las imágenes solo si el sistema aprieta, sin
    /// que haya que decidir aquí cuándo. Cada entrada ronda los 0,9 MB.
    @ObservationIgnored
    private let cache: NSCache<NSUUID, UIImage> = {
        let cache = NSCache<NSUUID, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    init(libraryUseCases: LibraryUseCases) {
        self.libraryUseCases = libraryUseCases
    }

    /// Carátula de una canción a `maxPixelSize`, de la caché si está.
    /// Devuelve `nil` si la canción no tiene carátula guardada; quien llama se queda con su
    /// thumbnail.
    func image(for songID: UUID, maxPixelSize: Int = cardMaxPixelSize) async -> UIImage? {
        if let cached = cache.object(forKey: songID as NSUUID) {
            return cached
        }

        guard let song = try? await libraryUseCases.getSongByID(songID),
              let artworkData = song.artworkData else { return nil }

        guard let image = await ArtworkDecoder.decode(artworkData, maxPixelSize: maxPixelSize) else {
            return nil
        }

        cache.setObject(image, forKey: songID as NSUUID, cost: image.estimatedBytes)
        return image
    }
}

private extension UIImage {
    /// Tamaño en memoria de la imagen decodificada: el `cost` que `NSCache` necesita para
    /// aplicar su límite en bytes (el tamaño del fichero no sirve, está comprimido).
    var estimatedBytes: Int {
        guard let cgImage else { return 0 }
        return cgImage.height * cgImage.bytesPerRow
    }
}
