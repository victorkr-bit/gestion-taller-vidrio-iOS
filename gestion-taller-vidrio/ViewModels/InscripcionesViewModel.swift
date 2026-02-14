import Foundation
import Combine
import FirebaseFirestore

@MainActor
class InscripcionesViewModel: ObservableObject {

    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Lista principal de inscripciones
    @Published var inscripciones: [Inscripcion] = []

    // Caché de Pagos por Inscripción (Acordeón)
    @Published var pagosPorInscripcion: [String: [Pago]] = [:]

    @Published var ocupacionPorInscripcion: [String: Int] = [:]

    // Listeners
    private var inscripcionesListener: ListenerRegistration?
    private var paymentListeners: [String: ListenerRegistration] = [:]
    private let taskTracker = TaskTracker()

    // MARK: - Dependencias
    private let tallerRepo: TallerRepository
    private let finanzasRepo: FinanzasRepository
    let ventasRepo: VentasRepository

    init(tallerRepo: TallerRepository, finanzasRepo: FinanzasRepository, ventasRepo: VentasRepository) {
        self.tallerRepo = tallerRepo
        self.finanzasRepo = finanzasRepo
        self.ventasRepo = ventasRepo
    }

    deinit {
        taskTracker.cancelAll()
        paymentListeners.values.forEach { $0.remove() }
        inscripcionesListener?.remove()
    }

    // MARK: - Lógica de Inscripciones

    func fetchInscripciones(cronogramaID: String) {
        isLoading = true
        errorMessage = nil
        inscripcionesListener?.remove()

        inscripcionesListener = tallerRepo.listenToInscripciones(cronogramaID: cronogramaID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let lista):
                self.inscripciones = lista
                self.calcularOcupaciones(para: lista)
            case .failure(let error):
                self.errorMessage = "Error en inscripciones: \(error.localizedDescription)"
            }
        }
    }

    func fetchInscripcionesOnline(cursoID: String) {
        isLoading = true
        errorMessage = nil
        inscripcionesListener?.remove()

        inscripcionesListener = tallerRepo.listenToInscripcionesOnline(cursoID: cursoID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let lista):
                self.inscripciones = lista
            case .failure(let error):
                self.errorMessage = "Error en inscripciones online: \(error.localizedDescription)"
            }
        }
    }

    func saveInscripcion(inscripcion: Inscripcion) {
        taskTracker.track(Task {
            do {
                try await tallerRepo.saveInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al guardar la inscripción: \(error.localizedDescription)"
            }
        })
    }

    func deleteInscripcion(_ inscripcion: Inscripcion) {
        guard inscripcion.monto_abonado == 0 else {
            errorMessage = "No se puede eliminar la inscripción porque tiene pagos registrados. Eliminá los pagos primero."
            return
        }

        taskTracker.track(Task {
            do {
                try await tallerRepo.deleteInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al eliminar inscripción: \(error.localizedDescription)"
            }
        })
    }

    private func calcularOcupaciones(para lista: [Inscripcion]) {
        var ocupaciones: [String: Int] = [:]
        for inscripcion in lista {
            guard let id = inscripcion.id else { continue }
            let ocupacion = TallerCalculator.calcularOcupacion(para: inscripcion, enLista: lista)
            ocupaciones[id] = ocupacion
        }
        self.ocupacionPorInscripcion = ocupaciones
    }

    // MARK: - Lógica de Pagos

    func fetchPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        if paymentListeners[id] != nil { return } // Ya estamos escuchando

        if pagosPorInscripcion[id] == nil {
            pagosPorInscripcion[id] = []
        }

        let listener = finanzasRepo.listenToPagos(origenID: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosPorInscripcion[id] = pagos
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(error.localizedDescription)"
            }
        }

        paymentListeners[id] = listener
    }

    func stopListeningPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        paymentListeners[id]?.remove()
        paymentListeners[id] = nil
    }

    func cleanupPaymentListeners() {
        paymentListeners.values.forEach { $0.remove() }
        paymentListeners.removeAll()
        pagosPorInscripcion.removeAll()
    }

    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        try await finanzasRepo.registrarPago(pago: pago, origen: origen)
    }
}
