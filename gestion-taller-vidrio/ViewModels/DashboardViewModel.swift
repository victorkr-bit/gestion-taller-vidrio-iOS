import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Estado de la UI
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Filtros de Fecha
    @Published var mesInicio: MesAño = .current() {
        didSet { restartPagosListener(); loadDetalleClases() }
    }

    @Published var mesFin: MesAño = .current() {
        didSet { restartPagosListener(); loadDetalleClases() }
    }
    
    // MARK: - KPIs Financieros
    @Published var totalIngresosMes: Double = 0.0
    @Published var totalDeuda: Double = 0.0
    @Published var pagosDelMes: [Pago] = []

    // MARK: - Datos de Gráficos (pre-calculados)
    @Published var datosGraficoPorTipo: [DatoGraficoTipo] = []
    @Published var facturacionAnual: [DatoMensual] = []

    // MARK: - KPIs Operativos
    @Published var proximasClases: [CronogramaItem] = []
    @Published var ocupacionesTaller: [OcupacionTallerItem] = []
    @Published var detalleClases = DetalleClases(taller: nil, presencial: [], online: [])
    
    // Listeners
    private var metricasListener: ListenerRegistration?
    private var pagosListener: ListenerRegistration?
    private var cronogramaListener: ListenerRegistration?
    private var anualListener: ListenerRegistration?
    private var inscripcionListeners: [String: ListenerRegistration] = [:]
    private var currentTalleres: [String: CronogramaItem] = [:]
    private let taskTracker = TaskTracker()
    
    // MARK: - Inyección de Dependencias
    
    private let finanzasRepo: FinanzasRepository
    private let tallerRepo: TallerRepository
    
    init(finanzasRepo: FinanzasRepository? = nil, tallerRepo: TallerRepository? = nil) {
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        self.tallerRepo = tallerRepo ?? TallerRepository()
        setupListeners()
    }
    
    deinit {
        taskTracker.cancelAll()
        metricasListener?.remove()
        pagosListener?.remove()
        cronogramaListener?.remove()
        anualListener?.remove()
        inscripcionListeners.values.forEach { $0.remove() }
    }
    
    func setupListeners() {
        isLoading = true

        // 1. Escuchar Métricas Globales
        metricasListener?.remove()
        metricasListener = finanzasRepo.listenToMetricas { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let metricas):
                self.totalDeuda = metricas.total_deuda_pedidos + metricas.total_deuda_inscripciones
            case .failure(let error):
                self.errorMessage = "Error cargando métricas: \(error.localizedDescription)"
            }
        }

        // 2. Escuchar Pagos (filtrado por fechas)
        restartPagosListener()

        // 3. Escuchar Agenda
        listenToProximaClase()

        // 4. Escuchar Facturación Anual (ventana fija 12 meses)
        listenToFacturacionAnual()

        // 5. Cargar detalle de clases por período
        loadDetalleClases()
    }

    private func restartPagosListener() {
        pagosListener?.remove()

        pagosListener = finanzasRepo.listenToPagos(from: mesInicio.fechaInicio, to: mesFin.fechaFin) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosDelMes = pagos
                self.totalIngresosMes = pagos.reduce(0) { $0 + $1.monto }
                self.recalcularDatosGraficos(pagos)
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(error.localizedDescription)"
            }
        }
    }
    
    private func listenToProximaClase() {
        cronogramaListener?.remove()

        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let proximos):
                self.proximasClases = Array(proximos.prefix(2))

                let talleres = proximos.prefix(2).filter { $0.cursoTipo == .taller }
                let tallerIDs = Set(talleres.compactMap { $0.id })
                self.ocupacionesTaller.removeAll { !tallerIDs.contains($0.id) }

                // Actualizar mapa de talleres actuales
                self.currentTalleres = [:]
                for t in talleres { if let id = t.id { self.currentTalleres[id] = t } }

                // Actualizar títulos de items existentes
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
                self.errorMessage = "Error sincronizando agenda: \(error.localizedDescription)"
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
                self.errorMessage = "Error calculando ocupación: \(error.localizedDescription)"
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
    
    func refreshData() {
        setupListeners()
    }

    // MARK: - Cálculo de Datos para Gráficos

    private func recalcularDatosGraficos(_ pagos: [Pago]) {
        let totalGlobal = pagos.reduce(0) { $0 + $1.monto }

        // Por Tipo de Venta
        let agrupadosPorTipo = Dictionary(grouping: pagos) { $0.tipo_venta.descripcion }
        self.datosGraficoPorTipo = agrupadosPorTipo.map { (tipo, pagosGrupo) in
            let montoGrupo = pagosGrupo.reduce(0) { $0 + $1.monto }
            let porcentaje = totalGlobal > 0 ? Int((montoGrupo / totalGlobal) * 100) : 0
            return DatoGraficoTipo(tipo: tipo, monto: montoGrupo, porcentaje: porcentaje)
        }.sorted { $0.monto > $1.monto }
    }

    private func listenToFacturacionAnual() {
        anualListener?.remove()
        let cal = Calendar.current
        let inicioVentana = cal.date(byAdding: .month, value: -12, to: MesAño.current().fechaInicio)!
        let finVentana = MesAño.current().fechaFin

        anualListener = finanzasRepo.listenToPagos(from: inicioVentana, to: finVentana) { [weak self] result in
            guard let self = self else { return }
            if case .success(let pagos) = result { self.calcularFacturacionAnual(pagos: pagos) }
        }
    }

    private func loadDetalleClases() {
        taskTracker.track(Task {
            do {
                let ahora = Date()
                let fechaInicio = self.mesInicio.fechaInicio
                guard fechaInicio <= ahora else {
                    self.detalleClases = DetalleClases(taller: nil, presencial: [], online: [])
                    return
                }
                let fechaFin = min(self.mesFin.fechaFin, ahora)
                let ins = try await self.tallerRepo.fetchInscripcionesPorFecha(
                    from: fechaInicio,
                    to: fechaFin
                )
                self.computeDetalleClases(ins)
            } catch { /* fallo silencioso — info secundaria */ }
        })
    }

    private func computeDetalleClases(_ inscripciones: [Inscripcion]) {
        // Taller
        let tallerIns = inscripciones.filter { $0.cursoTipo == .taller }
        let taller: DetalleTaller? = tallerIns.isEmpty ? nil : DetalleTaller(
            clases: Set(tallerIns.compactMap { $0.cronogramaId }).count,
            alumnos: tallerIns.count
        )

        // Presencial — agrupado por cursoNombre
        let presencialIns = inscripciones.filter { $0.cursoTipo == .presencial }
        let presencial = Dictionary(grouping: presencialIns) { $0.cursoNombre }
            .map { nombre, ins in
                DetalleCurso(nombre: nombre,
                             clases: Set(ins.compactMap { $0.cronogramaId }).count,
                             alumnos: ins.count)
            }
            .sorted { $0.alumnos > $1.alumnos }

        // Online — agrupado por cursoNombre, sin conteo de clases
        let onlineIns = inscripciones.filter { $0.cursoTipo == .online }
        let online = Dictionary(grouping: onlineIns) { $0.cursoNombre }
            .map { nombre, ins in DetalleCurso(nombre: nombre, clases: nil, alumnos: ins.count) }
            .sorted { $0.alumnos > $1.alumnos }

        self.detalleClases = DetalleClases(taller: taller, presencial: presencial, online: online)
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

    // MARK: - Computed Properties para UI

    var periodoLabel: String {
        if mesInicio == mesFin {
            return mesInicio.shortLabel
        } else if mesInicio.año == mesFin.año {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "es_AR")
            let inicioStr = cal.shortMonthSymbols[mesInicio.mes - 1].capitalized
            return "\(inicioStr) – \(mesFin.shortLabel)"
        } else {
            return "\(mesInicio.shortLabel) – \(mesFin.shortLabel)"
        }
    }

    var tendenciaPorcentaje: Double {
        let cal = Calendar.current
        let duracion = mesRange
        var totalAnterior: Double = 0
        for i in 1...duracion {
            guard let fecha = cal.date(byAdding: .month, value: -i, to: mesInicio.fechaInicio) else { continue }
            let m = cal.component(.month, from: fecha)
            let a = cal.component(.year, from: fecha)
            totalAnterior += facturacionAnual.first { $0.mes == m && $0.año == a }?.total ?? 0
        }
        guard totalAnterior > 0 else { return 0 }
        return ((totalIngresosMes - totalAnterior) / totalAnterior) * 100
    }

    private var mesRange: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month], from: mesInicio.fechaInicio, to: mesFin.fechaFin)
        return max(1, (comps.month ?? 0) + 1)
    }
}

// MARK: - Structs de detalle de clases

struct DetalleClases {
    var taller: DetalleTaller?
    var presencial: [DetalleCurso]
    var online: [DetalleCurso]
    var tieneContenido: Bool { taller != nil || !presencial.isEmpty || !online.isEmpty }
}

struct DetalleTaller {
    let clases: Int
    let alumnos: Int
}

struct DetalleCurso: Identifiable {
    var id: String { nombre }
    let nombre: String
    let clases: Int?  // nil para Online
    let alumnos: Int
}

// MARK: - Structs de ocupación

struct OcupacionTallerItem: Identifiable {
    let id: String
    let titulo: String
    let datos: [OcupacionHoraDato]
}

// MARK: - Structs de datos para gráficos

struct DatoGraficoTipo: Identifiable {
    let id = UUID()
    let tipo: String
    let monto: Double
    let porcentaje: Int
}

struct DatoMensual: Identifiable {
    var id: String { "\(año)-\(mes)" }
    let mes: Int
    let año: Int
    let total: Double

    var label: String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")
        return "\(cal.shortMonthSymbols[mes - 1].capitalized) \(año)"
    }

    var esMesActual: Bool {
        let c = Calendar.current, now = Date()
        return mes == c.component(.month, from: now) && año == c.component(.year, from: now)
    }

    var esAñoAnterior: Bool {
        año < Calendar.current.component(.year, from: Date())
    }
}
