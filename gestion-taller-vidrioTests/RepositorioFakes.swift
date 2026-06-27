import Foundation
@testable import gestion_taller_vidrio

/// Error sintético para stubs de fallo.
struct ErrorDePrueba: Error {}

// MARK: - FinanzasRepositorioFake

@MainActor
final class FinanzasRepositorioFake: FinanzasRepositorio {

    // Stubs configurables
    var pagosStub: [Pago] = []
    var deudoresStub: [DeudorItem] = []
    var resumenDeudaStub: (real: Double, futuro: Double) = (0, 0)
    var metricasStub = MetricasFinancieras()
    var errorStub: Error?

    // Captura de listeners (el test emite cuando quiere, sincrónicamente)
    private(set) var pagosRangoCompletion: ((Result<[Pago], Error>) -> Void)?
    private(set) var ultimoRango: (from: Date?, to: Date?)?
    private(set) var metricasCompletion: ((Result<MetricasFinancieras, Error>) -> Void)?
    private(set) var pagosPorOrigenCompletions: [String: (Result<[Pago], Error>) -> Void] = [:]

    // Registro de llamadas
    private(set) var registrarPagoLlamadas: [(pago: Pago, origen: Origen)] = []
    private(set) var editPagoLlamadas: [(pago: Pago, montoAntiguo: Double)] = []
    private(set) var deletePagoLlamadas: [Pago] = []
    private(set) var ventaDirectaLlamadas: [Pago] = []
    private(set) var fetchDeudoresLlamadas = 0
    private(set) var rangosRecibidos: [(from: Date?, to: Date?)] = []

    // Spies de cancelación
    private(set) var cancelacionesRango = 0
    private(set) var cancelacionesPorOrigen: [String: Int] = [:]
    private(set) var cancelacionesMetricas = 0

    // Emisores
    func emitirPagos(_ pagos: [Pago]) { pagosRangoCompletion?(.success(pagos)) }
    func emitirErrorPagos(_ error: Error) { pagosRangoCompletion?(.failure(error)) }
    func emitirMetricas(_ metricas: MetricasFinancieras) { metricasCompletion?(.success(metricas)) }
    func emitirPagos(origenID: String, _ pagos: [Pago]) { pagosPorOrigenCompletions[origenID]?(.success(pagos)) }

    // MARK: FinanzasRepositorio

    func fetchPagos(from: Date?, to: Date?) async throws -> [Pago] {
        try lanzarSiHayError()
        return pagosStub
    }

    func fetchPagos(origenID: String) async throws -> [Pago] {
        try lanzarSiHayError()
        return pagosStub
    }

    func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        ultimoRango = (from, to)
        rangosRecibidos.append((from, to))
        pagosRangoCompletion = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesRango += 1 }
    }

    func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        pagosPorOrigenCompletions[origenID] = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesPorOrigen[origenID, default: 0] += 1 }
    }

    func registrarPago(pago: Pago, origen: Origen) async throws {
        try lanzarSiHayError()
        registrarPagoLlamadas.append((pago, origen))
    }

    func editPago(pagoActualizado: Pago, montoAntiguo: Double) async throws {
        try lanzarSiHayError()
        editPagoLlamadas.append((pagoActualizado, montoAntiguo))
    }

    func deletePago(pago: Pago) async throws {
        try lanzarSiHayError()
        deletePagoLlamadas.append(pago)
    }

    func saveVentaDirecta(pago: Pago) async throws {
        try lanzarSiHayError()
        ventaDirectaLlamadas.append(pago)
    }

    func fetchResumenDeuda() async throws -> (real: Double, futuro: Double) {
        try lanzarSiHayError()
        return resumenDeudaStub
    }

    func fetchDeudores() async throws -> [DeudorItem] {
        fetchDeudoresLlamadas += 1
        try lanzarSiHayError()
        return deudoresStub
    }

    func fetchMetricasFinancieras() async throws -> MetricasFinancieras {
        try lanzarSiHayError()
        return metricasStub
    }

    func listenToMetricas(completion: @escaping (Result<MetricasFinancieras, Error>) -> Void) -> SuscripcionActiva {
        metricasCompletion = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesMetricas += 1 }
    }

    private func lanzarSiHayError() throws {
        if let error = errorStub { throw error }
    }
}

// MARK: - TallerRepositorioFake

@MainActor
final class TallerRepositorioFake: TallerRepositorio {

    // Stubs configurables
    var cursosStub: [Curso] = []
    var cronogramaStub: [CronogramaItem] = []
    var cronogramaItemStub: CronogramaItem?
    var inscripcionesStub: [Inscripcion] = []
    var saveCursoStub: (cronogramas: Int, inscripciones: Int)?
    var errorStub: Error?

    // Captura de listeners
    private(set) var inscripcionesCompletions: [String: (Result<[Inscripcion], Error>) -> Void] = [:]
    private(set) var inscripcionesOnlineCompletions: [String: (Result<[Inscripcion], Error>) -> Void] = [:]
    private(set) var preinscripcionesCompletions: [String: (Result<[Preinscripcion], Error>) -> Void] = [:]
    private(set) var cursosProximosCompletion: ((Result<[CronogramaItem], Error>) -> Void)?
    private(set) var cursosCompletion: ((Result<[Curso], Error>) -> Void)?
    private(set) var catalogoOnlineCompletion: ((Result<[Curso], Error>) -> Void)?

    // Registro de llamadas
    private(set) var saveInscripcionLlamadas: [Inscripcion] = []
    private(set) var deleteInscripcionLlamadas: [Inscripcion] = []
    private(set) var moverInscripcionLlamadas: [(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool)] = []
    private(set) var rangosFechaPedidos: [(from: Date, to: Date)] = []
    private(set) var saveCursoLlamadas: [Curso] = []
    private(set) var deleteCursoLlamadas: [Curso] = []
    private(set) var fetchInscripcionesByAlumnoLlamadas: [String] = []
    private(set) var actualizarCronogramaLlamadas: [(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?, nuevoCupo: Int?, horaInicio: String?, horaFin: String?)] = []
    private(set) var confirmarPreinscripcionLlamadas: [(id: String, monto: Double, medio: MedioDePago)] = []
    private(set) var cancelarPreinscripcionLlamadas: [String] = []

    // Spies de cancelación
    private(set) var cancelacionesInscripciones: [String: Int] = [:]
    private(set) var cancelacionesInscripcionesOnline: [String: Int] = [:]
    private(set) var cancelacionesPreinscripciones: [String: Int] = [:]
    private(set) var cancelacionesCronograma = 0
    private(set) var cancelacionesCatalogo = 0

    // Emisores
    func emitirInscripciones(cronogramaID: String, _ lista: [Inscripcion]) {
        inscripcionesCompletions[cronogramaID]?(.success(lista))
    }
    func emitirErrorInscripciones(cronogramaID: String, _ error: Error) {
        inscripcionesCompletions[cronogramaID]?(.failure(error))
    }
    func emitirInscripcionesOnline(cursoID: String, _ lista: [Inscripcion]) {
        inscripcionesOnlineCompletions[cursoID]?(.success(lista))
    }
    func emitirCursosProximos(_ items: [CronogramaItem]) {
        cursosProximosCompletion?(.success(items))
    }
    func emitirCursos(_ cursos: [Curso]) {
        cursosCompletion?(.success(cursos))
    }
    func emitirErrorCursos(_ error: Error) {
        cursosCompletion?(.failure(error))
    }
    func emitirCatalogoOnline(_ cursos: [Curso]) {
        catalogoOnlineCompletion?(.success(cursos))
    }
    func emitirErrorCatalogo(_ error: Error) {
        catalogoOnlineCompletion?(.failure(error))
    }
    func emitirPreinscripciones(cronogramaID: String, _ lista: [Preinscripcion]) {
        preinscripcionesCompletions[cronogramaID]?(.success(lista))
    }
    func emitirErrorPreinscripciones(cronogramaID: String, _ error: Error) {
        preinscripcionesCompletions[cronogramaID]?(.failure(error))
    }

    // MARK: TallerRepositorio

    func fetchCursos() async throws -> [Curso] {
        try lanzarSiHayError()
        return cursosStub
    }

    func listenToCursos(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        cursosCompletion = completion
        return SuscripcionActiva { }
    }

    func saveCurso(curso: Curso) async throws -> (cronogramas: Int, inscripciones: Int)? {
        try lanzarSiHayError()
        saveCursoLlamadas.append(curso)
        return saveCursoStub
    }

    func deleteCurso(curso: Curso) async throws {
        try lanzarSiHayError()
        deleteCursoLlamadas.append(curso)
    }

    func fetchCatalogoOnline() async throws -> [Curso] {
        try lanzarSiHayError()
        return cursosStub
    }

    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        catalogoOnlineCompletion = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesCatalogo += 1 }
    }

    func fetchCursosProximos() async throws -> [CronogramaItem] {
        try lanzarSiHayError()
        return cronogramaStub
    }

    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> SuscripcionActiva {
        cursosProximosCompletion = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesCronograma += 1 }
    }

    func fetchCursosHistoricos() async throws -> [CronogramaItem] {
        try lanzarSiHayError()
        return cronogramaStub
    }

    func fetchCronogramaItem(id: String) async throws -> CronogramaItem? {
        try lanzarSiHayError()
        return cronogramaItemStub
    }

    func saveCronogramaItem(item: CronogramaItem) async throws {
        try lanzarSiHayError()
    }

    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?, nuevoCupo: Int?, horaInicio: String?, horaFin: String?) async throws {
        try lanzarSiHayError()
        actualizarCronogramaLlamadas.append((id, nuevoPrecio, nuevaFecha, nuevasNotas, nuevoCupo, horaInicio, horaFin))
    }

    func deleteCronogramaItem(item: CronogramaItem) async throws {
        try lanzarSiHayError()
    }

    func fetchInscripciones(cronogramaID: String) async throws -> [Inscripcion] {
        try lanzarSiHayError()
        return inscripcionesStub
    }

    func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        inscripcionesCompletions[cronogramaID] = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesInscripciones[cronogramaID, default: 0] += 1 }
    }

    func listenToInscripcionesOnline(cursoID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        inscripcionesOnlineCompletions[cursoID] = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesInscripcionesOnline[cursoID, default: 0] += 1 }
    }

    @discardableResult
    func saveInscripcion(inscripcion: Inscripcion) async throws -> Inscripcion {
        try lanzarSiHayError()
        saveInscripcionLlamadas.append(inscripcion)
        var saved = inscripcion
        if saved.id == nil { saved.id = "inscripcion-creada" }
        return saved
    }

    func moverInscripcion(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool) async throws {
        try lanzarSiHayError()
        moverInscripcionLlamadas.append((inscripcionId, destinoCronogramaId, adoptarPrecio))
    }

    func deleteInscripcion(inscripcion: Inscripcion) async throws {
        try lanzarSiHayError()
        deleteInscripcionLlamadas.append(inscripcion)
    }

    func fetchInscripcionesByAlumno(alumnoId: String) async throws -> [Inscripcion] {
        fetchInscripcionesByAlumnoLlamadas.append(alumnoId)
        try lanzarSiHayError()
        return inscripcionesStub
    }

    func fetchInscripcionesPorFecha(from: Date, to: Date) async throws -> [Inscripcion] {
        rangosFechaPedidos.append((from, to))
        try lanzarSiHayError()
        return inscripcionesStub
    }

    func listenToPreinscripciones(cronogramaID: String, completion: @escaping (Result<[Preinscripcion], Error>) -> Void) -> SuscripcionActiva {
        preinscripcionesCompletions[cronogramaID] = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesPreinscripciones[cronogramaID, default: 0] += 1 }
    }

    func confirmarPreinscripcion(preinscripcionId: String, monto: Double, medioDePago: MedioDePago) async throws {
        try lanzarSiHayError()
        confirmarPreinscripcionLlamadas.append((preinscripcionId, monto, medioDePago))
    }

    func cancelarPreinscripcion(preinscripcionId: String) async throws {
        try lanzarSiHayError()
        cancelarPreinscripcionLlamadas.append(preinscripcionId)
    }

    private func lanzarSiHayError() throws {
        if let error = errorStub { throw error }
    }
}

// MARK: - VentasRepositorioFake

@MainActor
final class VentasRepositorioFake: VentasRepositorio {

    var pedidosStub: [Pedido] = []
    var errorStub: Error?

    private(set) var pedidosCompletion: ((Result<[Pedido], Error>) -> Void)?
    private(set) var savePedidoLlamadas: [(pedido: Pedido, existingID: String?)] = []
    private(set) var deletePedidoLlamadas: [Pedido] = []
    private(set) var cancelacionesPedidos = 0
    private(set) var suscripcionesPedidos = 0

    func emitirPedidos(_ pedidos: [Pedido]) { pedidosCompletion?(.success(pedidos)) }
    func emitirErrorPedidos(_ error: Error) { pedidosCompletion?(.failure(error)) }

    // MARK: VentasRepositorio

    func fetchPedidos(limit: Int) async throws -> [Pedido] {
        try lanzarSiHayError()
        return pedidosStub
    }

    func listenToPedidos(completion: @escaping (Result<[Pedido], Error>) -> Void) -> SuscripcionActiva {
        suscripcionesPedidos += 1
        pedidosCompletion = completion
        return SuscripcionActiva { [weak self] in self?.cancelacionesPedidos += 1 }
    }

    func savePedido(pedido: Pedido, existingID: String?) async throws {
        try lanzarSiHayError()
        savePedidoLlamadas.append((pedido, existingID))
    }

    func deletePedido(pedido: Pedido) async throws {
        try lanzarSiHayError()
        deletePedidoLlamadas.append(pedido)
    }

    private func lanzarSiHayError() throws {
        if let error = errorStub { throw error }
    }
}

// MARK: - ContactosRepositorioFake

@MainActor
final class ContactosRepositorioFake: ContactosRepositorio {

    var contactosStub: [Contacto] = []
    var errorStub: Error?

    private(set) var saveContactoLlamadas: [(contacto: Contacto, uid: String)] = []
    private(set) var updateContactoLlamadas: [(contacto: Contacto, id: String)] = []
    private(set) var deleteContactoLlamadas: [Contacto] = []
    private(set) var fetchContactosLlamadas: [Bool] = [] // registra forceRefresh

    func fetchContactos(forceRefresh: Bool) async throws -> [Contacto] {
        fetchContactosLlamadas.append(forceRefresh)
        try lanzarSiHayError()
        return contactosStub
    }

    func saveContacto(_ contacto: Contacto, uid: String) async throws {
        try lanzarSiHayError()
        saveContactoLlamadas.append((contacto, uid))
    }

    func updateContacto(_ contacto: Contacto, id: String) async throws {
        try lanzarSiHayError()
        updateContactoLlamadas.append((contacto, id))
    }

    func deleteContacto(contacto: Contacto) async throws {
        try lanzarSiHayError()
        deleteContactoLlamadas.append(contacto)
    }

    private func lanzarSiHayError() throws {
        if let error = errorStub { throw error }
    }
}
