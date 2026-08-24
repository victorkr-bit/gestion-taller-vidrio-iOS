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

    // Preinscripciones pendientes (solo cursos presenciales), ya filtradas y ordenadas
    @Published var preinscripciones: [Preinscripcion] = []

    // Conteo de preinscriptos pendientes por cronogramaId, para las cards de lista
    @Published var preinscriptosPorCronograma: [String: Int] = [:]

    // Listeners
    private var inscripcionesListener: SuscripcionActiva?
    private var preinscripcionesListener: SuscripcionActiva?
    private var preinscriptosGlobalListener: SuscripcionActiva?
    private var paymentListeners: [String: SuscripcionActiva] = [:]
    private let taskTracker = TaskTracker()

    // MARK: - Dependencias
    private let tallerRepo: any TallerRepositorio
    private let finanzasRepo: any FinanzasRepositorio
    let contactosRepo: any ContactosRepositorio

    init(tallerRepo: any TallerRepositorio, finanzasRepo: any FinanzasRepositorio, contactosRepo: any ContactosRepositorio) {
        self.tallerRepo = tallerRepo
        self.finanzasRepo = finanzasRepo
        self.contactosRepo = contactosRepo
    }

    isolated deinit {
        paymentListeners.values.forEach { $0.remove() }
        inscripcionesListener?.remove()
        preinscripcionesListener?.remove()
        preinscriptosGlobalListener?.remove()
    }

    // MARK: - Lógica de Inscripciones

    func fetchInscripciones(cronogramaID: String) {
        isLoading = true
        errorMessage = nil
        inscripciones = []
        inscripcionesListener?.remove()

        inscripcionesListener = tallerRepo.listenToInscripciones(cronogramaID: cronogramaID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let lista):
                self.inscripciones = lista
                self.calcularOcupaciones(para: lista)
            case .failure(let error):
                self.errorMessage = "Error en inscripciones: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    func fetchInscripcionesOnline(cursoID: String) {
        isLoading = true
        errorMessage = nil
        inscripciones = []
        inscripcionesListener?.remove()

        inscripcionesListener = tallerRepo.listenToInscripcionesOnline(cursoID: cursoID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let lista):
                self.inscripciones = lista
            case .failure(let error):
                self.errorMessage = "Error en inscripciones online: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    func saveInscripcion(inscripcion: Inscripcion) {
        taskTracker.track(Task {
            do {
                _ = try await tallerRepo.saveInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al guardar la inscripción: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func guardarInscripcionConPago(inscripcion: Inscripcion, montoPago: Double, medioDePago: MedioDePago, pagosSplit: [PagoSplitEntry]? = nil) {
        taskTracker.track(Task {
            do {
                let saved = try await tallerRepo.saveInscripcion(inscripcion: inscripcion)
                let montoTotal = pagosSplit?.reduce(0) { $0 + $1.monto } ?? montoPago
                guard montoTotal > 0 else { return }
                let origen = Origen.inscripcion(saved)
                let pago = Pago(
                    fecha: Date(),
                    monto: montoTotal,
                    medio_de_pago: pagosSplit?.first?.medioDePago ?? medioDePago,
                    cliente_id: origen.clienteID,
                    cliente_nombre: origen.clienteNombre,
                    tipo_venta: origen.tipoVenta,
                    notas: nil,
                    origen_tipo: origen.tipo,
                    descripcion_origen: origen.descripcionOrigen,
                    origen_id: origen.id
                )
                try await finanzasRepo.registrarPago(pago: pago, origen: origen, pagosSplit: pagosSplit)
            } catch {
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        })
    }

    func deleteInscripcion(_ inscripcion: Inscripcion) {
        guard inscripcion.monto_abonado == 0 else {
            errorMessage = "No se puede eliminar la inscripción porque tiene pagos registrados (puede incluir un adelanto que no aparece en Caja). Tocá la fila para ver el detalle de pagos y borrarlos primero."
            return
        }

        taskTracker.track(Task {
            do {
                try await tallerRepo.deleteInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al eliminar inscripción: \(FirestoreManager.mensajeAmigable(error))"
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
                self.errorMessage = "Error cargando pagos: \(FirestoreManager.mensajeAmigable(error))"
            }
        }

        paymentListeners[id] = listener
    }

    func stopListeningPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        paymentListeners[id]?.remove()
        paymentListeners[id] = nil
    }

    func stopListeningInscripciones() {
        inscripcionesListener?.remove()
        inscripcionesListener = nil
        isLoading = false
        inscripciones = []
        ocupacionPorInscripcion = [:]
    }

    func cleanupPaymentListeners() {
        paymentListeners.values.forEach { $0.remove() }
        paymentListeners.removeAll()
        pagosPorInscripcion.removeAll()
    }

    func registrarPago(pago: Pago, origen: Origen, pagosSplit: [PagoSplitEntry]? = nil) async throws {
        errorMessage = nil
        try await finanzasRepo.registrarPago(pago: pago, origen: origen, pagosSplit: pagosSplit)
    }

    /// Borra un pago desde el acordeón de una inscripción (incluye los de categoría "adelanto",
    /// que no aparecen en la Caja global y por eso necesitan poder borrarse desde acá).
    func deletePago(_ pago: Pago) {
        taskTracker.track(Task {
            do {
                try await finanzasRepo.deletePago(pago: pago)
            } catch {
                self.errorMessage = "No se pudo borrar el pago: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func moverInscripcion(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool) async throws {
        errorMessage = nil
        try await tallerRepo.moverInscripcion(
            inscripcionId: inscripcionId,
            destinoCronogramaId: destinoCronogramaId,
            adoptarPrecio: adoptarPrecio
        )
    }

    // MARK: - Preinscripciones (cursos presenciales)

    /// Suscribe el listener de preinscripciones del cronograma. Filtra `pendiente` en memoria
    /// y ordena por fecha de preinscripción ascendente (primero quien se preinscribió antes; nil al final).
    func fetchPreinscripciones(cronogramaID: String) {
        preinscripciones = []
        preinscripcionesListener?.remove()

        preinscripcionesListener = tallerRepo.listenToPreinscripciones(cronogramaID: cronogramaID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let lista):
                self.preinscripciones = lista
                    .filter { $0.estado == .pendiente }
                    .sorted { Self.fechaOrden($0) < Self.fechaOrden($1) }
            case .failure(let error):
                self.errorMessage = "Error en preinscripciones: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    /// Fecha de orden: las preinscripciones sin `fecha_preinscripcion` (serverTimestamp recién creado) van al final.
    private static func fechaOrden(_ p: Preinscripcion) -> Date {
        p.fecha_preinscripcion?.dateValue() ?? .distantFuture
    }

    /// Confirma el pago de una preinscripción. En éxito, el listener la quita sola (pasa a `convertida`).
    /// `contactoId`/`forzarContactoNuevo`: resolución manual del contacto elegida por el admin en
    /// `ConfirmarPreinscripcionView` (ver `ContactoMatching`); si ambos son `nil` el backend matchea automático.
    func confirmarPreinscripcion(_ preinscripcion: Preinscripcion, monto: Double, medioDePago: MedioDePago, pagosSplit: [PagoSplitEntry]? = nil, contactoId: String? = nil, forzarContactoNuevo: Bool? = nil) async throws {
        guard let id = preinscripcion.id else { return }
        errorMessage = nil
        try await tallerRepo.confirmarPreinscripcion(preinscripcionId: id, monto: monto, medioDePago: medioDePago, pagosSplit: pagosSplit, contactoId: contactoId, forzarContactoNuevo: forzarContactoNuevo)
    }

    /// Descarta una preinscripción (la marca como cancelada).
    func descartarPreinscripcion(_ preinscripcion: Preinscripcion) {
        guard let id = preinscripcion.id else { return }
        taskTracker.track(Task {
            do {
                try await tallerRepo.cancelarPreinscripcion(preinscripcionId: id)
            } catch {
                self.errorMessage = "Error al descartar la preinscripción: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func stopListeningPreinscripciones() {
        preinscripcionesListener?.remove()
        preinscripcionesListener = nil
        preinscripciones = []
    }

    /// Escucha TODAS las preinscripciones pendientes y las agrupa por cronogramaId.
    /// Usado por AgendaListView para mostrar el conteo de preinscriptos en cada card.
    func subscribeToPreinscriptosGlobal() {
        preinscriptosGlobalListener?.remove()
        preinscriptosGlobalListener = tallerRepo.listenToPreinscripcionesPendientes { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let lista):
                let pendientes = lista.filter { $0.estado == .pendiente }
                self.preinscriptosPorCronograma = Dictionary(grouping: pendientes, by: \.cronogramaId)
                    .mapValues(\.count)
            case .failure(let error):
                self.errorMessage = "Error en preinscriptos: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    func unsubscribeFromPreinscriptosGlobal() {
        preinscriptosGlobalListener?.remove()
        preinscriptosGlobalListener = nil
        preinscriptosPorCronograma = [:]
    }
}
