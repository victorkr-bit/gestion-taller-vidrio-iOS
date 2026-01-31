import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Estado de la UI
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Filtros de Fecha (RESTAURADOS)
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
    @Published var pagosDelMes: [Pago] = [] // Para gráfico de torta
    
    // MARK: - KPIs Operativos
    @Published var proximaClase: CronogramaItem? = nil
    
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
        
        // Configuración inicial de fechas: Todo el mes actual por defecto
        let calendar = Calendar.current
        let now = Date()
        
        // Inicio del mes
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        self.fechaInicio = startOfMonth
        
        // Fin del mes (calculado sumando 1 mes y restando 1 día)
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
        // Ajustamos al final del día (23:59:59)
        self.fechaFin = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        
        // Iniciamos listeners
        setupListeners()
    }
    
    deinit {
        metricasListener?.remove()
        pagosListener?.remove()
    }
    
    func setupListeners() {
        isLoading = true
        
        // 1. Escuchar Métricas Globales (Deuda Total - Siempre es histórica, no depende del filtro de fecha)
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
        
        // 2. Escuchar Pagos (Depende de fechaInicio y fechaFin)
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
        
        // 3. Obtener Próxima Clase
        Task {
            do {
                let proximos = try await tallerRepo.fetchCursosProximos()
                self.proximaClase = proximos.first
                self.isLoading = false
            } catch {
                self.errorMessage = "Error cargando agenda: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func refreshData() {
        setupListeners()
    }
}
