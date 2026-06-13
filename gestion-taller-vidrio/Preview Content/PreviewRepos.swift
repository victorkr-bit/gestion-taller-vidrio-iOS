#if DEBUG
import Foundation

/// Repos de preview (solo DEBUG). Conforman los protocolos sin tocar Firebase.
/// Los `listenToX` **emiten de forma diferida** (próximo runloop vía `Task`), igual
/// que Firestore real: así no se mutan `@Published` durante la construcción del
/// view tree (evita el crash "Publishing changes from within view updates" que
/// dejaba la preview en loop de rebuild). Las escrituras son no-op.

// MARK: - Finanzas

@MainActor
final class FinanzasRepositorioPreview: FinanzasRepositorio {
    var pagos: [Pago]
    var deudores: [DeudorItem]
    var metricas: MetricasFinancieras
    var resumenDeuda: (real: Double, futuro: Double)

    init(pagos: [Pago] = PreviewData.pagos,
         deudores: [DeudorItem] = PreviewData.deudores,
         metricas: MetricasFinancieras = PreviewData.metricas,
         resumenDeuda: (real: Double, futuro: Double) = PreviewData.resumenDeuda) {
        self.pagos = pagos
        self.deudores = deudores
        self.metricas = metricas
        self.resumenDeuda = resumenDeuda
    }

    func fetchPagos(from: Date?, to: Date?) async throws -> [Pago] { pagos }
    func fetchPagos(origenID: String) async throws -> [Pago] {
        pagos.filter { $0.origen_id == origenID }
    }

    func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        let datos = pagos
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }

    func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        let datos = pagos.filter { $0.origen_id == origenID }
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }

    func registrarPago(pago: Pago, origen: Origen) async throws {}
    func editPago(pagoActualizado: Pago, montoAntiguo: Double) async throws {}
    func deletePago(pago: Pago) async throws {}
    func saveVentaDirecta(pago: Pago) async throws {}

    func fetchResumenDeuda() async throws -> (real: Double, futuro: Double) { resumenDeuda }
    func fetchDeudores() async throws -> [DeudorItem] { deudores }
    func fetchMetricasFinancieras() async throws -> MetricasFinancieras { metricas }

    func listenToMetricas(completion: @escaping (Result<MetricasFinancieras, Error>) -> Void) -> SuscripcionActiva {
        let datos = metricas
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
}

// MARK: - Taller

@MainActor
final class TallerRepositorioPreview: TallerRepositorio {
    var cursos: [Curso]
    var catalogoOnline: [Curso]
    var proximos: [CronogramaItem]
    var historico: [CronogramaItem]
    var inscripciones: [Inscripcion]
    var inscripcionesOnline: [Inscripcion]

    init(cursos: [Curso] = PreviewData.cursos,
         catalogoOnline: [Curso] = PreviewData.cursosOnline,
         proximos: [CronogramaItem] = PreviewData.cronogramaProximos,
         historico: [CronogramaItem] = PreviewData.cronogramaHistorico,
         inscripciones: [Inscripcion] = PreviewData.inscripciones,
         inscripcionesOnline: [Inscripcion] = PreviewData.inscripcionesOnline) {
        self.cursos = cursos
        self.catalogoOnline = catalogoOnline
        self.proximos = proximos
        self.historico = historico
        self.inscripciones = inscripciones
        self.inscripcionesOnline = inscripcionesOnline
    }

    func fetchCursos() async throws -> [Curso] { cursos }
    func listenToCursos(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        let datos = cursos
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
    func saveCurso(curso: Curso) async throws -> (cronogramas: Int, inscripciones: Int)? { nil }
    func deleteCurso(curso: Curso) async throws {}

    func fetchCatalogoOnline() async throws -> [Curso] { catalogoOnline }
    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        let datos = catalogoOnline
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }

    func fetchCursosProximos() async throws -> [CronogramaItem] { proximos }
    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> SuscripcionActiva {
        let datos = proximos
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
    func fetchCursosHistoricos(limit: Int) async throws -> [CronogramaItem] { historico }
    func fetchCronogramaItem(id: String) async throws -> CronogramaItem? {
        proximos.first { $0.id == id } ?? historico.first { $0.id == id }
    }
    func saveCronogramaItem(item: CronogramaItem) async throws {}
    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?) async throws {}
    func deleteCronogramaItem(item: CronogramaItem) async throws {}

    func fetchInscripciones(cronogramaID: String) async throws -> [Inscripcion] {
        inscripciones.filter { $0.cronogramaId == cronogramaID }
    }
    func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        let datos = inscripciones.filter { $0.cronogramaId == cronogramaID }
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
    func listenToInscripcionesOnline(cursoID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        let datos = inscripcionesOnline.filter { $0.cursoId == cursoID }
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
    func saveInscripcion(inscripcion: Inscripcion) async throws -> Inscripcion { inscripcion }
    func moverInscripcion(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool) async throws {}
    func deleteInscripcion(inscripcion: Inscripcion) async throws {}
    func fetchInscripcionesByAlumno(alumnoId: String) async throws -> [Inscripcion] {
        (inscripciones + inscripcionesOnline).filter { $0.alumnoId == alumnoId }
    }
    func fetchInscripcionesPorFecha(from: Date, to: Date) async throws -> [Inscripcion] { inscripciones }
}

// MARK: - Ventas

@MainActor
final class VentasRepositorioPreview: VentasRepositorio {
    var pedidos: [Pedido]

    init(pedidos: [Pedido] = PreviewData.pedidos) {
        self.pedidos = pedidos
    }

    func fetchPedidos(limit: Int) async throws -> [Pedido] { pedidos }
    func listenToPedidos(completion: @escaping (Result<[Pedido], Error>) -> Void) -> SuscripcionActiva {
        let datos = pedidos
        Task { @MainActor in completion(.success(datos)) }
        return SuscripcionActiva {}
    }
    func savePedido(pedido: Pedido, existingID: String?) async throws {}
    func deletePedido(pedido: Pedido) async throws {}
}

// MARK: - Contactos

@MainActor
final class ContactosRepositorioPreview: ContactosRepositorio {
    var contactos: [Contacto]

    init(contactos: [Contacto] = PreviewData.contactos) {
        self.contactos = contactos
    }

    func fetchContactos(forceRefresh: Bool) async throws -> [Contacto] { contactos }
    func saveContacto(_ contacto: Contacto, uid: String) async throws {}
    func updateContacto(_ contacto: Contacto, id: String) async throws {}
    func deleteContacto(contacto: Contacto) async throws {}
}
#endif
