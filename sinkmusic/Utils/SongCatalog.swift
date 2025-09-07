
import Foundation

struct SongCatalog {
    
    // Este es el único lugar que necesitarás modificar para añadir o quitar canciones.
    // Ahora es un diccionario [ID_del_archivo: Nombre_de_la_canción]
    static let allSongs: [String: String] = [
        "1UywGyACXjM1DHHu9fRgYahstKslAi2dK": "Canción de Prueba 1",
        "1EAhgmaVu6b41qMKd0v3aTFQdfX7wImaP": "Canción de Prueba 2",
        "1j_nv-N28u9EDzv962j5JjEb8z4Ue-5cw": "Canción de Prueba 3",
        "16wwAcd1ESxdr4kmH0idNvLpw4U48-7nW": "Canción de Prueba 4",
        "1U9YeQYECqHihgEzVLJGw3CPEg_7_pD-D": "Canción de Prueba 5"
    ]
    
    // Un utilitario para obtener el título, o un título por defecto si no se encuentra
    static func title(for fileID: String) -> String {
        return allSongs[fileID] ?? "Canción Desconocida (\(fileID.prefix(8))...)"
    }
}
