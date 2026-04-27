import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ProximaActividadViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var proximasClases: [CronogramaItem] = []
    @Published var ocupacionesTaller: [OcupacionTallerItem] = []

    private var cronogramaListener: ListenerRegistration?
    private var inscripcionListeners: [String: ListenerRegistration] = [:]
    private var currentTalleres: [String: CronogramaItem] = [:]

    private let tallerRepo: TallerRepository

    init(tallerRepo: TallerRepository) {
        self.tallerRepo = tallerRepo
        listenToProximaClase()
    }

    deinit {
        cronogramaListener?.remove()
        inscripcionListeners.values.forEach { $0.remove() }
    }

    private func listenToProximaClase() {
        isLoading = true
        cronogramaListener?.remove()

        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let proximos):
                self.proximasClases = Array(proximos.prefix(2))

                let talleres = proximos.prefix(2).filter { $0.cursoTipo == .taller }
                let tallerIDs = Set(talleres.compactMap { $0.id })
                self.ocupacionesTaller.removeAll { !tallerIDs.contains($0.id) }

                self.currentTalleres = [:]
                for t in talleres { if let id = t.id { self.currentTalleres[id] = t } }

                for (idx, item) in self.ocupacionesTaller.enumerated() {
                    if let taller = self.currentTalleres[item.id] {
                        let titulo = "\(taller.cursoNombre) · \(Formatters.date(taller.fecha))"
                        if item.titulo != titulo {
                            self.ocupacionesTaller[idx] = OcupacionTallerItem(id: item.id, titulo: titulo, datos: item.datos)
                        }
                    }
                }

                if talleres.isEmpty {
                    self.cleanupInscripcionListeners(keepIDs: [])
                } else {
                    for taller in talleres {
                        guard let id = taller.id else { continue }
                        if self.inscripcionListeners[id] == nil {
                            self.setupInscripcionListener(for: id)
                        }
                    }
                    self.cleanupInscripcionListeners(keepIDs: tallerIDs)
                }
                self.isLoading = false

            case .failure(let error):
                self.errorMessage = "Error sincronizando agenda: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        }
    }

    private func setupInscripcionListener(for cronogramaID: String) {
        inscripcionListeners[cronogramaID] = tallerRepo.listenToInscripciones(cronogramaID: cronogramaID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let inscripciones):
                guard let taller = self.currentTalleres[cronogramaID] else { return }
                let titulo = "\(taller.cursoNombre) · \(Formatters.date(taller.fecha))"
                let datos = TallerCalculator.calcularOcupacionPorHora(para: inscripciones)
                let item = OcupacionTallerItem(id: cronogramaID, titulo: titulo, datos: datos)
                if let idx = self.ocupacionesTaller.firstIndex(where: { $0.id == cronogramaID }) {
                    self.ocupacionesTaller[idx] = item
                } else {
                    self.ocupacionesTaller.append(item)
                }
            case .failure(let error):
                self.errorMessage = "Error calculando ocupación: \(FirestoreManager.mensajeAmigable(error))"
                self.ocupacionesTaller.removeAll { $0.id == cronogramaID }
            }
        }
    }

    private func cleanupInscripcionListeners(keepIDs: Set<String>) {
        for (id, listener) in inscripcionListeners where !keepIDs.contains(id) {
            listener.remove()
            inscripcionListeners.removeValue(forKey: id)
        }
    }
}
