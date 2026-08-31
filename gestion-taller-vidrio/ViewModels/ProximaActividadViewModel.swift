import Foundation
import Combine

@MainActor
class ProximaActividadViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var proximasClases: [CronogramaItem] = []
    @Published var ocupacionesTaller: [OcupacionTallerItem] = []

    private var cronogramaListener: SuscripcionActiva?

    private let tallerRepo: any TallerRepositorio

    init(tallerRepo: any TallerRepositorio) {
        self.tallerRepo = tallerRepo
        listenToProximaClase()
    }

    isolated deinit {
        cronogramaListener?.remove()
    }

    private func listenToProximaClase() {
        isLoading = true
        cronogramaListener?.remove()

        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let proximos):
                let visibles = Array(proximos.prefix(2))
                self.proximasClases = visibles

                // La ocupación por hora la mantiene el backend en `slot_ocupacion`, así que
                // viene en el mismo doc de cronograma: no hace falta escuchar inscripciones.
                self.ocupacionesTaller = visibles
                    .filter { $0.cursoTipo == .taller }
                    .compactMap { taller in
                        guard let id = taller.id else { return nil }
                        return OcupacionTallerItem(
                            id: id,
                            titulo: "\(taller.cursoNombre) · \(Formatters.date(taller.fecha))",
                            datos: TallerCalculator.ocupacionPorHora(de: taller)
                        )
                    }
                self.isLoading = false

            case .failure(let error):
                self.errorMessage = "Error sincronizando agenda: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        }
    }
}
