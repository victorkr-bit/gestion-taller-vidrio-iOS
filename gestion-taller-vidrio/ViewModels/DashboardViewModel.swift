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
    @Published var proximaClase: CronogramaItem? = nil
    @Published var ocupacionTaller: [OcupacionHoraDato] = []
    @Published var detalleClases = DetalleClases(taller: nil, presencial: [], online: [])
    
    // Listeners
    private var metricasListener: ListenerRegistration?
    private var pagosListener: ListenerRegistration?
    private var cronogramaListener: ListenerRegistration?
    private var anualListener: ListenerRegistration?
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
    
    // Renombramos y cambiamos la lógica para usar Listeners en lugar de Fetch
    private func listenToProximaClase() {
        cronogramaListener?.remove()
        
        // Usamos la función del repo que ya existía: listenToCursosProximos
        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let proximos):
                let previousID = self.proximaClase?.id

                if let primera = proximos.first {
                    self.proximaClase = primera

                    // Solo recalcular si la próxima clase cambió
                    if primera.id != previousID, primera.cursoTipo == .taller, let id = primera.id {
                        self.taskTracker.track(Task { await self.loadOcupacion(cronogramaId: id) })
                    } else if primera.cursoTipo != .taller {
                        self.ocupacionTaller = []
                    }
                } else {
                    self.proximaClase = nil
                    self.ocupacionTaller = []
                }
                self.isLoading = false
                
            case .failure(let error):
                self.errorMessage = "Error sincronizando agenda: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func loadOcupacion(cronogramaId: String) async {
        do {
            let inscripciones = try await tallerRepo.fetchInscripciones(cronogramaID: cronogramaId)
            let datosGrafico = TallerCalculator.calcularOcupacionPorHora(para: inscripciones)
            self.ocupacionTaller = datosGrafico
        } catch {
            self.errorMessage = "Error calculando ocupación: \(error.localizedDescription)"
            self.ocupacionTaller = []
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
        let inicioVentana = cal.date(byAdding: .month, value: -11, to: MesAño.current().fechaInicio)!
        let finVentana = MesAño.current().fechaFin

        anualListener = finanzasRepo.listenToPagos(from: inicioVentana, to: finVentana) { [weak self] result in
            guard let self = self else { return }
            if case .success(let pagos) = result { self.calcularFacturacionAnual(pagos: pagos) }
        }
    }

    private func loadDetalleClases() {
        taskTracker.track(Task {
            do {
                let ins = try await self.tallerRepo.fetchInscripcionesPorFecha(
                    from: self.mesInicio.fechaInicio,
                    to: self.mesFin.fechaFin
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
        facturacionAnual = (0..<12).map { i in
            let date = cal.date(byAdding: .month, value: -i, to: now)!
            let m = cal.component(.month, from: date)
            let a = cal.component(.year, from: date)
            let total = pagos
                .filter { cal.component(.month, from: $0.fecha) == m && cal.component(.year, from: $0.fecha) == a }
                .reduce(0) { $0 + $1.monto }
            return DatoMensual(mes: m, año: a, total: total)
        }
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
}
