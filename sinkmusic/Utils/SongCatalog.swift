
import Foundation

import Foundation

struct CatalogSong: Identifiable {
    let id: String // Corresponde al fileID
    let title: String
    let artist: String
}

struct SongCatalog {
    
    // Este es el único lugar que necesitarás modificar para añadir o quitar canciones.
    static let allSongs: [CatalogSong] = [
        CatalogSong(id: "1UywGyACXjM1DHHu9fRgYahstKslAi2dK", title: "Paloma Ajena", artist: "Agua Marina"),
        CatalogSong(id: "1EAhgmaVu6b41qMKd0v3aTFQdfX7wImaP", title: "Asi es el Amor", artist: "Agua Marina"),
        CatalogSong(id: "1j_nv-N28u9EDzv962j5JjEb8z4Ue-5cw", title: "Herido Corazon", artist: "Armonia 10"),
        CatalogSong(id: "16wwAcd1ESxdr4kmH0idNvLpw4U48-7nW", title: "No te preocupes por mi", artist: "Corazon Serrano feat Dilbert Aguilar"),
        CatalogSong(id: "1U9YeQYECqHihgEzVLJGw3CPEg_7_pD-D", title: "Disjockey", artist: "Bella Luz"),
        CatalogSong(id: "1vu-7S2eJHV2P0hyGYKIaFPDAKJKJV2Ql", title: "Dont Stop Me Now", artist: "Queen"),
        CatalogSong(id: "1yMimmbkixLDLnZ-aznnz2bvZqgeyGXLr", title: "I Wanna Dance with Somebody", artist: "Whitney Houston"),
        CatalogSong(id: "1rBgk0KinKtM9CjdZzDrYXDxx9AzT8wu7", title: "Mix William Luna", artist: "Corazon Serrano"),
        CatalogSong(id: "1C3G-0wu59j2LbYdonUadZnkTDzRTWYSq", title: "We Are!", artist: "Hiroshi Kitadani")
    ]
    
    // Un utilitario para obtener el título, o un título por defecto si no se encuentra
    // Esta función podría no ser necesaria si siempre accedemos a través del array.
    static func song(for fileID: String) -> CatalogSong? {
        return allSongs.first(where: { $0.id == fileID })
    }
}
