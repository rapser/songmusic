//
//  HomePlaylistsOrderView.swift
//  sinkmusic
//
//  Elige qué playlists se muestran en Inicio y en qué orden.
//

import SwiftUI

/// Dos secciones reales en una sola `List`:
/// - **Reordenar dentro de una sección**: arrastrando con el control ≡ nativo (`.onMove`).
/// - **Cambiar de sección**: con el botón +/− de cada fila.
///
/// El cruce va por botón y no por arrastre porque SwiftUI no lo soporta: `.onMove` solo
/// reordena dentro de su propio `ForEach` y nunca entrega un arrastre que cruce de `Section`.
/// Las alternativas para lograrlo arrastrando obligan a renunciar a las `Section` reales
/// (encabezados como filas, que entonces también se pueden arrastrar) o a dividir la pantalla
/// en dos listas independientes. Con botones se conservan encabezados fijos y el arrastre
/// nativo donde sí funciona bien.
struct HomePlaylistsOrderView: View {
    @Environment(PlaylistViewModel.self) private var viewModel

    /// Margen lateral que `insetGrouped` aplica a sus secciones. El banner vive fuera de la
    /// `List`, así que replica este valor a mano para quedar del mismo ancho que las tarjetas.
    private let sectionHorizontalInset: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            // Fuera de la `List` a propósito: dentro, el recorte redondeado que `insetGrouped`
            // aplica a cada fila se comía las esquinas del borde punteado.
            infoBanner
                .padding(.horizontal, sectionHorizontalInset)
                .padding(.top, 10)

            List {
            Section {
                if viewModel.homeShownPlaylists.isEmpty {
                    emptyRow("Aún no tienes playlists en Inicio")
                } else {
                    ForEach(viewModel.homeShownPlaylists) { playlist in
                        row(playlist, isInHome: true)
                    }
                    .onMove { from, to in
                        viewModel.moveHomePlaylistWithinShown(fromOffsets: from, toOffset: to)
                    }
                }
            } header: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Inicio")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(viewModel.homeShownPlaylists.count) de \(PlaylistUseCases.maxHomePlaylistsCount)")
                        .font(.subheadline)
                        .foregroundColor(.textGray)
                }
                .textCase(nil)
            }

            Section {
                if viewModel.homeOtherPlaylists.isEmpty {
                    emptyRow("Aún no tienes más playlists")
                } else {
                    ForEach(viewModel.homeOtherPlaylists) { playlist in
                        row(playlist, isInHome: false)
                    }
                    .onMove { from, to in
                        viewModel.moveHomePlaylistWithinOthers(fromOffsets: from, toOffset: to)
                    }
                }
            } header: {
                Text("Otros")
                    .font(.headline)
                    .foregroundColor(.white)
                    .textCase(nil)
            }
            }
            .listStyle(.insetGrouped)
            // Recorta el margen superior que `insetGrouped` reserva antes de la primera
            // sección, para que "Inicio" quede pegado al banner.
            .contentMargins(.top, 8, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .background(Color.appDark)
        .navigationTitle("Editar inicio")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadHomePlaylistLayout()
        }
    }

    // MARK: - Subvistas

    private var infoBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.draw")
                .font(.title2)
                .foregroundColor(.appPurple)

            Text("Usa + y − para elegir qué playlists ver en Inicio, y ≡ para ordenarlas.")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `strokeBorder` en overlay dibuja el trazo hacia adentro del marco; con `stroke`
        // como background, la mitad del grosor queda fuera y el punteado se ve recortado.
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.textGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .listRowBackground(Color.appGray)
    }

    private func row(_ playlist: PlaylistUI, isInHome: Bool) -> some View {
        // El botón "+" se desactiva cuando Inicio ya llegó a su máximo.
        let isAddDisabled = !isInHome && viewModel.isHomePlaylistsFull

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Text(playlist.displayInfo)
                    .font(.caption)
                    .foregroundColor(.textGray)
            }

            Spacer()

            Button {
                if isInHome {
                    viewModel.movePlaylistToOthers(playlist.id)
                } else {
                    viewModel.movePlaylistToHome(playlist.id)
                }
            } label: {
                Image(systemName: isInHome ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isInHome ? .red : .appPurple)
            }
            .buttonStyle(.plain)
            .disabled(isAddDisabled)
            .opacity(isAddDisabled ? 0.3 : 1.0)
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.appGray)
    }
}

#Preview {
    NavigationStack {
        PreviewWrapper(
            playlistVM: PreviewViewModels.playlistVM(),
            modelContainer: PreviewData.container(with: PreviewSongs.generate())
        ) {
            HomePlaylistsOrderView()
        }
    }
}
