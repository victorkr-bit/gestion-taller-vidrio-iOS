import Foundation

// MARK: - SuscripcionActiva

/// Handle de un listener activo. Reemplaza ListenerRegistration en las firmas
/// públicas para que los ViewModels no dependan de tipos de Firebase y los
/// tests puedan inyectar fakes.
@MainActor
final class SuscripcionActiva {
    private let alCancelar: () -> Void

    init(alCancelar: @escaping () -> Void) {
        self.alCancelar = alCancelar
    }

    /// Mismo nombre que ListenerRegistration.remove() para no tocar call sites.
    func remove() {
        alCancelar()
    }
}

// MARK: - Protocolos de repositorio

@MainActor
protocol FinanzasRepositorio: Sendable {
    func fetchPagos(from: Date?, to: Date?) async throws -> [Pago]
    func fetchPagos(origenID: String) async throws -> [Pago]
    func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva
    func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva
    func registrarPago(pago: Pago, origen: Origen, pagosSplit: [PagoSplitEntry]?) async throws
    func editPago(pagoActualizado: Pago, montoAntiguo: Double) async throws
    func deletePago(pago: Pago) async throws
    func saveVentaDirecta(pago: Pago) async throws
    func fetchResumenDeuda() async throws -> (real: Double, futuro: Double)
    func fetchDeudores() async throws -> [DeudorItem]
    func fetchMetricasFinancieras() async throws -> MetricasFinancieras
    func listenToMetricas(completion: @escaping (Result<MetricasFinancieras, Error>) -> Void) -> SuscripcionActiva
}

@MainActor
protocol TallerRepositorio: Sendable {
    // Cursos (catálogo base)
    func fetchCursos() async throws -> [Curso]
    func listenToCursos(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva
    func saveCurso(curso: Curso) async throws -> (cronogramas: Int, inscripciones: Int)?
    func deleteCurso(curso: Curso) async throws
    func actualizarVisibilidadCurso(cursoId: String, visible: Bool) async throws
    // Cursos Online
    func fetchCatalogoOnline() async throws -> [Curso]
    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva
    // Cronograma
    func fetchCursosProximos() async throws -> [CronogramaItem]
    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> SuscripcionActiva
    func fetchCursosHistoricos(desde: Date?) async throws -> [CronogramaItem]
    func fetchCronogramaItem(id: String) async throws -> CronogramaItem?
    func saveCronogramaItem(item: CronogramaItem) async throws
    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?, nuevoCupo: Int?, horaInicio: String?, horaFin: String?) async throws
    func deleteCronogramaItem(item: CronogramaItem) async throws
    // Inscripciones
    func fetchInscripciones(cronogramaID: String) async throws -> [Inscripcion]
    func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva
    func listenToInscripcionesOnline(cursoID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva
    @discardableResult
    func saveInscripcion(inscripcion: Inscripcion) async throws -> Inscripcion
    func moverInscripcion(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool) async throws
    func deleteInscripcion(inscripcion: Inscripcion) async throws
    func fetchInscripcionesByAlumno(alumnoId: String) async throws -> [Inscripcion]
    func fetchInscripcionesPorFecha(from: Date, to: Date) async throws -> [Inscripcion]
    // Preinscripciones (cursos presenciales)
    func listenToPreinscripciones(cronogramaID: String, completion: @escaping (Result<[Preinscripcion], Error>) -> Void) -> SuscripcionActiva
    func listenToPreinscripcionesPendientes(completion: @escaping (Result<[Preinscripcion], Error>) -> Void) -> SuscripcionActiva
    func confirmarPreinscripcion(preinscripcionId: String, monto: Double, medioDePago: MedioDePago, pagosSplit: [PagoSplitEntry]?, contactoId: String?, forzarContactoNuevo: Bool?) async throws
    func cancelarPreinscripcion(preinscripcionId: String) async throws
}

@MainActor
protocol VentasRepositorio: Sendable {
    func fetchPedidos(limit: Int) async throws -> [Pedido]
    func listenToPedidos(completion: @escaping (Result<[Pedido], Error>) -> Void) -> SuscripcionActiva
    func savePedido(pedido: Pedido, existingID: String?) async throws
    func deletePedido(pedido: Pedido) async throws
}

@MainActor
protocol ContactosRepositorio: Sendable {
    func fetchContactos(forceRefresh: Bool) async throws -> [Contacto]
    func saveContacto(_ contacto: Contacto, uid: String) async throws
    func updateContacto(_ contacto: Contacto, id: String) async throws
    func deleteContacto(contacto: Contacto) async throws
}

// MARK: - Conveniencias (los protocolos no admiten valores por defecto)

extension VentasRepositorio {
    func fetchPedidos() async throws -> [Pedido] { try await fetchPedidos(limit: 50) }
    func savePedido(pedido: Pedido) async throws { try await savePedido(pedido: pedido, existingID: nil) }
}

extension FinanzasRepositorio {
    func registrarPago(pago: Pago, origen: Origen) async throws {
        try await registrarPago(pago: pago, origen: origen, pagosSplit: nil)
    }
}

extension TallerRepositorio {
    func confirmarPreinscripcion(preinscripcionId: String, monto: Double, medioDePago: MedioDePago) async throws {
        try await confirmarPreinscripcion(preinscripcionId: preinscripcionId, monto: monto, medioDePago: medioDePago, pagosSplit: nil, contactoId: nil, forzarContactoNuevo: nil)
    }
    func fetchCursosHistoricos() async throws -> [CronogramaItem] { try await fetchCursosHistoricos(desde: nil) }
}


extension ContactosRepositorio {
    func fetchContactos() async throws -> [Contacto] { try await fetchContactos(forceRefresh: false) }
}
