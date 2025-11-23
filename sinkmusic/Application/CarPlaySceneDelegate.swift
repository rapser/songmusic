//
//  CarPlaySceneDelegate.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import CarPlay
import SwiftData

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Configurar el template de CarPlay
        setupCarPlayInterface()
    }

    private func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    private func setupCarPlayInterface() {
        guard let interfaceController = interfaceController else { return }

        // CarPlay para apps de audio se basa principalmente en:
        // 1. MPNowPlayingInfoCenter (ya configurado en AudioPlayerService)
        // 2. MPRemoteCommandCenter (ya configurado en AudioPlayerService)
        // 3. CPNowPlayingTemplate para la interfaz de reproducción

        // Configurar botones adicionales si es necesario
        // Por defecto, CarPlay ya muestra los controles de reproducción desde MPRemoteCommandCenter

        // Crear una lista simple para la biblioteca de música
        let listTemplate = CPListTemplate(
            title: "SinkMusic",
            sections: [
                CPListSection(items: [
                    createNowPlayingItem()
                ])
            ]
        )

        listTemplate.tabImage = UIImage(systemName: "music.note.list")
        listTemplate.tabTitle = "Música"

        // El template de Now Playing se accede automáticamente cuando hay música reproduciéndose
        // No es necesario agregarlo manualmente al tab bar

        // Establecer el template como raíz
        let tabBarTemplate = CPTabBarTemplate(templates: [listTemplate])
        interfaceController.setRootTemplate(tabBarTemplate, animated: true, completion: nil)
    }

    private func createNowPlayingItem() -> CPListItem {
        let item = CPListItem(text: "Reproduciendo ahora", detailText: "Ver reproductor")

        // Acción al seleccionar el item
        item.handler = { [weak self] _, completion in
            // Mostrar el template de Now Playing
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }

        if let image = UIImage(systemName: "play.circle.fill") {
            item.setImage(image)
        }

        return item
    }
}
