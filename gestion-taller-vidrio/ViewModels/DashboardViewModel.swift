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
    // Usamos didSet para recargar los datos cuando el usuario cambia la fecha en MainView
    @Published var fechaInicio: Date = Date() {
        didSet { refreshData() }
    }
    
    @Published var fechaFin: Date = Date() {
        didSet { refreshData() }
    }
    
    // MARK: - KPIs Financieros
    @Published var totalIngresosMes: Double = 0.0
    @Published var totalDeuda: Double = 0.0
    @Published var pagosDelMes: [Pago] = [] // Para gráfico de barras
    
    // MARK: - KPIs Operativos
    @Published var proximaClase: CronogramaItem? = nil
    // NUEVO: Datos para el gráfico de ocupación por hora
    @Published var ocupacionTaller: [OcupacionHoraDato] = []
    
    // Listeners
    private var metricasListener: ListenerRegistration?
    private var pagosListener: ListenerRegistration?
    
    // MARK: - Inyección de Dependencias
    
    private let finanzasRepo: FinanzasRepository
    private let tallerRepo: TallerRepository
    
    // Inicializador con Instanciación Perezosa
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
            // Ajustamos al final del día (23:59:59)
            self.fechaFin = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        } else {
            self.fechaFin = now
        }
        
        // Iniciamos listeners
        setupListeners()
    }
    
    deinit {
        metricasListener?.remove()
        pagosListener?.remove()
    }
    
    func setupListeners() {
        isLoading = true
        
        // 1. Escuchar Métricas Globales (Deuda Total)
        metricasListener?.remove()
        metricasListener = finanzasRepo.listenToMetricas { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let metricas):
                self.totalDeuda = metricas.total_deuda_pedidos + metricas.total_deuda_inscripciones
            case .failure(let error):
                print("Error metricas: \(error)")
            }
        }
        
        // 2. Escuchar Pagos (Filtrado por fechas)
        pagosListener?.remove()
        
        // Aseguramos que fechaFin cubra hasta el último segundo del día seleccionado
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: fechaFin) ?? fechaFin
        
        pagosListener = finanzasRepo.listenToPagos(from: fechaInicio, to: endOfDay) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosDelMes = pagos
                self.totalIngresosMes = pagos.reduce(0) { $0 + $1.monto }
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(error.localizedDescription)"
            }
        }
        
        // 3. Obtener Próxima Clase y Calcular Ocupación
        loadProximaClase()
    }
    
    // Función separada para la lógica asíncrona de agenda
    private func loadProximaClase() {
        Task {
            do {
                let proximos = try await tallerRepo.fetchCursosProximos()
                
                if let primera = proximos.first {
                    self.proximaClase = primera
                    
                    // LÓGICA DE OCUPACIÓN:
                    // Si es un Taller y tiene ID, calculamos la ocupación por hora
                    if primera.cursoTipo == .taller, let id = primera.id {
                        await loadOcupacion(cronogramaId: id)
                    } else {
                        // Si es Online o Presencial (sin turnos), limpiamos el gráfico
                        self.ocupacionTaller = []
                    }
                } else {
                    self.proximaClase = nil
                    self.ocupacionTaller = []
                }
                
                self.isLoading = false
            } catch {
                self.errorMessage = "Error cargando agenda: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // Función auxiliar para calcular ocupación específica
    private func loadOcupacion(cronogramaId: String) async {
        do {
            let inscripciones = try await tallerRepo.fetchInscripciones(cronogramaID: cronogramaId)
            // Usamos el helper matemático TallerCalculator
            let datosGrafico = TallerCalculator.calcularOcupacionPorHora(para: inscripciones)
            self.ocupacionTaller = datosGrafico
        } catch {
            print("Error calculando ocupación: \(error)")
            self.ocupacionTaller = []
        }
    }
    
    func refreshData() {
        setupListeners()
    }
}
