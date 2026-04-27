import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ChartsViewModel: ObservableObject {

    @Published var errorMessage: String?

    @Published var facturacionAnual: [DatoMensual] = []
    @Published var clasesAnuales: [DatoMensualClases] = []
    @Published var detalleClases = DetalleClases(taller: nil, presencial: [], online: [])

    private var anualListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let taskTracker = TaskTracker()

    private let finanzasRepo: FinanzasRepository
    private let tallerRepo: TallerRepository
    private let filter: FilterCoordinator

    init(finanzasRepo: FinanzasRepository, tallerRepo: TallerRepository, filter: FilterCoordinator) {
        self.finanzasRepo = finanzasRepo
        self.tallerRepo = tallerRepo
        self.filter = filter

        listenToFacturacionAnual()
        loadClasesAnuales()
        loadDetalleClases()
        observeFilter()
    }

    deinit {
        taskTracker.cancelAll()
        anualListener?.remove()
    }

    private func observeFilter() {
        filter.$mesInicio
            .combineLatest(filter.$mesFin)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.loadDetalleClases()
            }
            .store(in: &cancellables)
    }

    // MARK: - Facturación anual (ventana fija 12 meses)

    private func listenToFacturacionAnual() {
        anualListener?.remove()
        let cal = Calendar.current
        let inicioVentana = cal.date(byAdding: .month, value: -12, to: MesAño.current().fechaInicio)!
        let finVentana = MesAño.current().fechaFin

        anualListener = finanzasRepo.listenToPagos(from: inicioVentana, to: finVentana) { [weak self] result in
            guard let self = self else { return }
            if case .success(let pagos) = result {
                self.calcularFacturacionAnual(pagos: pagos)
            }
        }
    }

    private func calcularFacturacionAnual(pagos: [Pago]) {
        let cal = Calendar.current
        let now = Date()
        facturacionAnual = (0..<13).map { i in
            let date = cal.date(byAdding: .month, value: -i, to: now)!
            let m = cal.component(.month, from: date)
            let a = cal.component(.year, from: date)
            let total = pagos
                .filter { cal.component(.month, from: $0.fecha) == m && cal.component(.year, from: $0.fecha) == a }
                .reduce(0) { $0 + $1.monto }
            return DatoMensual(mes: m, año: a, total: total)
        }
    }

    // MARK: - Clases anuales (ventana fija 12 meses)

    private func loadClasesAnuales() {
        taskTracker.track(Task {
            do {
                let cal = Calendar.current
                let ahora = Date()
                let inicioVentana = cal.date(byAdding: .month, value: -11, to: MesAño.current().fechaInicio)!
                let ins = try await self.tallerRepo.fetchInscripcionesPorFecha(from: inicioVentana, to: ahora)

                self.clasesAnuales = (0..<12).map { i in
                    let mesDate = cal.date(byAdding: .month, value: -(11 - i), to: MesAño.current().fechaInicio)!
                    let m = cal.component(.month, from: mesDate)
                    let a = cal.component(.year, from: mesDate)
                    let delMes = ins.filter {
                        cal.component(.month, from: $0.fecha_curso) == m &&
                        cal.component(.year, from: $0.fecha_curso) == a
                    }
                    let clases = Set(delMes.compactMap { $0.cronogramaId }).count
                    return DatoMensualClases(mes: m, año: a, clases: clases, alumnos: delMes.count)
                }
            } catch { /* fallo silencioso */ }
        })
    }

    // MARK: - Detalle de clases del período (depende del filter)

    private func loadDetalleClases() {
        taskTracker.track(Task {
            do {
                let ahora = Date()
                let fechaInicio = self.filter.mesInicio.fechaInicio
                guard fechaInicio <= ahora else {
                    self.detalleClases = DetalleClases(taller: nil, presencial: [], online: [])
                    return
                }
                let fechaFin = min(self.filter.mesFin.fechaFin, ahora)
                let ins = try await self.tallerRepo.fetchInscripcionesPorFecha(
                    from: fechaInicio,
                    to: fechaFin
                )
                self.computeDetalleClases(ins)
            } catch { /* fallo silencioso */ }
        })
    }

    private func computeDetalleClases(_ inscripciones: [Inscripcion]) {
        let tallerIns = inscripciones.filter { $0.cursoTipo == .taller }
        let taller: DetalleTaller? = tallerIns.isEmpty ? nil : DetalleTaller(
            clases: Set(tallerIns.compactMap { $0.cronogramaId }).count,
            alumnos: tallerIns.count
        )

        let presencialIns = inscripciones.filter { $0.cursoTipo == .presencial }
        let presencial = Dictionary(grouping: presencialIns) { $0.cursoNombre }
            .map { nombre, ins in
                DetalleCurso(nombre: nombre,
                             clases: Set(ins.compactMap { $0.cronogramaId }).count,
                             alumnos: ins.count)
            }
            .sorted { $0.alumnos > $1.alumnos }

        let onlineIns = inscripciones.filter { $0.cursoTipo == .online }
        let online = Dictionary(grouping: onlineIns) { $0.cursoNombre }
            .map { nombre, ins in DetalleCurso(nombre: nombre, clases: nil, alumnos: ins.count) }
            .sorted { $0.alumnos > $1.alumnos }

        self.detalleClases = DetalleClases(taller: taller, presencial: presencial, online: online)
    }
}
