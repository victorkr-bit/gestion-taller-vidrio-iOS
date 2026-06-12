import Foundation
import Combine

@MainActor
class CatalogoOnlineViewModel: ObservableObject {

    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var catalogoOnline: [Curso] = []

    // Listener
    private var catalogoListener: SuscripcionActiva?

    // MARK: - Dependencia
    private let tallerRepo: any TallerRepositorio

    init(tallerRepo: any TallerRepositorio) {
        self.tallerRepo = tallerRepo
    }

    isolated deinit {
        catalogoListener?.remove()
    }

    // MARK: - Lógica Online

    func stopListening() {
        catalogoListener?.remove()
        catalogoListener = nil
    }

    func subscribeToCatalogoOnline() {
        isLoading = true
        errorMessage = nil
        catalogoListener?.remove()

        catalogoListener = tallerRepo.listenToCatalogoOnline { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let cursos):
                self.catalogoOnline = cursos.sorted { $0.nombre < $1.nombre }
            case .failure(let error):
                self.errorMessage = "Error sincronizando catálogo: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }
}
