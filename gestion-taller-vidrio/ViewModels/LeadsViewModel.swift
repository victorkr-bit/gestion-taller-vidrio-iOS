import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class LeadsViewModel: ObservableObject {

    @Published var leads: [Lead] = []
    @Published var filtroTexto: String = ""
    @Published var filtroEstado: EstadoLead? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var cronogramaProximos: [CronogramaItem] = []

    private let tallerRepo: TallerRepository
    private var listener: ListenerRegistration?
    private var tasks = TaskTracker()

    var leadsFiltrados: [Lead] {
        leads.filter { lead in
            let textoOk = filtroTexto.isEmpty
                || lead.nombre.localizedCaseInsensitiveContains(filtroTexto)
                || lead.curso_interes.localizedCaseInsensitiveContains(filtroTexto)
            let estadoOk = filtroEstado == nil || lead.estado == filtroEstado
            return textoOk && estadoOk
        }
    }

    init(tallerRepo: TallerRepository) {
        self.tallerRepo = tallerRepo
        listener = tallerRepo.listenToLeads { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let leads):
                self.leads = leads
            case .failure(let error):
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        }
    }

    deinit {
        listener?.remove()
    }

    func marcarNotificado(leads: [Lead]) {
        let ids = leads.compactMap(\.id)
        guard !ids.isEmpty else { return }
        tasks.track(Task {
            do {
                try await tallerRepo.actualizarEstadoLeads(ids: ids, estado: .notificado)
            } catch {
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        })
    }

    func fetchCronogramaProximos() {
        tasks.track(Task {
            do {
                self.cronogramaProximos = try await tallerRepo.fetchCursosProximos()
            } catch { }
        })
    }

    func borrarLead(_ lead: Lead) {
        guard let id = lead.id else { return }
        tasks.track(Task {
            do {
                _ = try await FirestoreManager.shared.functions
                    .httpsCallable("borrarEntidad")
                    .call(["id": id, "coleccion": "leads"])
            } catch {
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        })
    }

    func convertirLead(_ lead: Lead) async throws -> String {
        guard let id = lead.id else {
            throw TallerError.transaccionFallida("Lead sin ID")
        }
        let result = try await FirestoreManager.shared.functions
            .httpsCallable("convertirLead").call(["leadId": id])
        guard let data = result.data as? [String: Any],
              let contactoId = data["contactoId"] as? String else {
            throw TallerError.transaccionFallida("Respuesta inesperada del servidor")
        }
        return contactoId
    }
}
