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
    @Published var fechaInicio: Date = Date() {
        didSet { restartPagosListener() }
    }

    @Published var fechaFin: Date = Date() {
        didSet { restartPagosListener() }
    }
    
    // MARK: - KPIs Financieros
    @Published var totalIngresosMes: Double = 0.0
    @Published var totalDeuda: Double = 0.0
    @Published var pagosDelMes: [Pago] = []

    // MARK: - Datos de Gráficos (pre-calculados)
    @Published var datosGraficoPorTipo: [DatoGraficoTipo] = []
    @Published var datosGraficoPorMedio: [DatoGraficoMedio] = []

    // MARK: - KPIs Operativos
    @Published var proximaClase: CronogramaItem? = nil
    @Published var ocupacionTaller: [OcupacionHoraDato] = []
    
    // Listeners
    private var metricasListener: ListenerRegistration?
    private var pagosListener: ListenerRegistration?
    // NUEVO: Listener para que la agenda se actualice sola
    private var cronogramaListener: ListenerRegistration?
    private let taskTracker = TaskTracker()
    
    // MARK: - Inyección de Dependencias
    
    private let finanzasRepo: FinanzasRepository
    private let tallerRepo: TallerRepository
    
    init(finanzasRepo: FinanzasRepository? = nil, tallerRepo: TallerRepository? = nil) {
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        self.tallerRepo = tallerRepo ?? TallerRepository()
        
        // Configuración inicial de fechas (ROBUSTA)
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Calcular Inicio del Mes (Forzando día 1)
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        let startOfMonth = calendar.date(from: components) ?? now
        self.fechaInicio = startOfMonth
        
        // 2. Calcular Fin del Mes
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
            let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? now
            self.fechaFin = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        } else {
            self.fechaFin = now
        }
        
        // Iniciamos listeners
        setupListeners()
    }
    
    deinit {
        taskTracker.cancelAll()
        metricasListener?.remove()
        pagosListener?.remove()
        cronogramaListener?.remove()
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
    }

    private func restartPagosListener() {
        pagosListener?.remove()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: fechaFin) ?? fechaFin

        pagosListener = finanzasRepo.listenToPagos(from: fechaInicio, to: endOfDay) { [weak self] result in
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

        // Por Medio de Pago
        let agrupadosPorMedio = Dictionary(grouping: pagos) { $0.medio_de_pago.rawValue }
        self.datosGraficoPorMedio = agrupadosPorMedio.map { (medio, pagosGrupo) in
            let montoGrupo = pagosGrupo.reduce(0) { $0 + $1.monto }
            let porcentaje = totalGlobal > 0 ? Int((montoGrupo / totalGlobal) * 100) : 0
            return DatoGraficoMedio(medio: medio, monto: montoGrupo, porcentaje: porcentaje)
        }.sorted { $0.monto > $1.monto }
    }
}

// MARK: - Structs de datos para gráficos

struct DatoGraficoTipo: Identifiable {
    let id = UUID()
    let tipo: String
    let monto: Double
    let porcentaje: Int
}

struct DatoGraficoMedio: Identifiable {
    let id = UUID()
    let medio: String
    let monto: Double
    let porcentaje: Int
}
