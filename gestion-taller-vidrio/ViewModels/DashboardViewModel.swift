import Foundation
import Combine
import SwiftUI
import FirebaseFirestore // Necesario para ListenerRegistration

// Struct para el gráfico de torta (Sin cambios)
struct IngresoPorTipo: Identifiable {
    var id: TipoVenta { tipo }
    let tipo: TipoVenta
    var monto: Double
}

@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Estado
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Fechas
    @Published var fechaInicio: Date = Date().inicioDelMes()
    @Published var fechaFin: Date = Date().finDelMes()
    
    // KPIs
    @Published var totalIngresos: Double = 0
    @Published var totalDeuda: Double = 0
    
    // Gráficos
    @Published var ingresosPorTipo: [IngresoPorTipo] = []
    @Published var ocupacionTaller: [OcupacionHoraDato] = []
    
    @Published var proximaActividad: CronogramaItem? = nil
    @Published var inscripcionesProximaActividad: [Inscripcion] = []
    
    // CAMBIO 1: La fuente de verdad para el gráfico ahora es este modelo optimizado
    @Published var ingresosUI: [IngresoUIModel] = []
    
    // MARK: - Dependencias y Listeners
    private let repository = FirestoreTallerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Variable para controlar la suscripción a los pagos (Ingresos)
    private var pagosListener: ListenerRegistration?
    
    // Nueva variable para controlar la suscripción a inscripciones
    private var inscripcionesListener: ListenerRegistration?
    
    // Variable para controlar la suscripción a métricas
    private var metricasListener: ListenerRegistration?
    
    
    // MARK: - Init
    
    init() {
        // Configuración de reactividad ante cambios de fecha
        Publishers.CombineLatest($fechaInicio, $fechaFin)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] (inicio, fin) in
                guard let self = self else { return }
                self.actualizarDashboard(inicio: inicio, fin: fin)
            }
            .store(in: &cancellables)
        
        // Primera carga manual (o dejada al sink inicial si Combine dispara al inicio)
        // CombineLatest dispara al inicio si sus properties tienen valor inicial.
    }
    
    deinit {
        metricasListener?.remove()
        pagosListener?.remove()
        inscripcionesListener?.remove()
    }
    
    // MARK: - Lógica Principal
    
    // Esta función coordina todo
    private func actualizarDashboard(inicio: Date, fin: Date) {
        // 1. Suscripción a Ingresos (Gráfico de torta - Filtro por fecha)
        subscribeToPagos(inicio: inicio, fin: fin)
        
        // 2. Suscripción a Deuda Total (KPI GLOBAL - Tiempo Real)
        // Ya no depende de las fechas del filtro, es la deuda histórica total.
        subscribeToDeudaGlobal()
        
        // 3. Carga de actividades próximas (Esto puede seguir siendo estático o volverse listener si quieres)
        Task {
            try? await fetchProximaActividadYGrafico()
        }
    }
    
    private func subscribeToDeudaGlobal() {
        // Evitamos duplicar listeners si ya existe uno
        if metricasListener != nil { return }
        
        metricasListener = repository.listenToMetricas{ [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let metricas):
                // ¡Magia! Se actualiza solo en cuanto llega el dato nuevo
                self.totalDeuda = metricas.deudaTotal
                
            case .failure(let error):
                print("Error escuchando métricas: \(error.localizedDescription)")
                // Opcional: self.errorMessage = ...
            }
        }
    }
    
    // --- PARTE 1: REAL TIME (Ingresos) ---
    private func subscribeToPagos(inicio: Date, fin: Date) {
        isLoading = true // Mostramos carga brevemente al cambiar fechas
        
        // Limpiamos listener anterior si existe
        pagosListener?.remove()
        
        // Iniciamos nueva escucha con el repositorio (Reusamos la función que creamos para la Caja)
        pagosListener = repository.listenToPagos(from: inicio, to: fin) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let pagos):
                // Cada vez que hay un cambio en pagos, recalculamos los KPIs
                self.calcularKPIsIngresos(pagos: pagos)
            case .failure(let error):
                self.errorMessage = "Error en ingresos: \(error.localizedDescription)"
            }
        }
    }
    
    // --- PARTE 2: FETCH (Deuda y Actividades) ---
    private func fetchDataEstatica() {
        Task {
            do {
                // A. KPI DEUDA (Rápido y barato: 1 documento)
                let metricas = try await repository.fetchMetricasFinancieras()
                await MainActor.run {
                    self.totalDeuda = metricas.deudaTotal
                }
                
                // B. LISTA DE PROXIMA ACTIVIDAD (Igual que antes)
                try await fetchProximaActividadYGrafico()
                
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Lógica de Cálculos (Cliente)
    
    private func calcularKPIsIngresos(pagos: [Pago]) {
        // 1. Cálculo total (Rápido)
        let total = pagos.reduce(0) { $0 + $1.monto }
        self.totalIngresos = total
        
        // 2. Agrupación
        let agrupados = Dictionary(grouping: pagos, by: { $0.tipo_venta })
        
        // 3. Mapeo a modelo de UI (HEAVY LIFTING AQUÍ, NO EN LA VISTA)
        let uiModels = agrupados.map { (tipo, pagosDelTipo) -> IngresoUIModel in
            let montoTipo = pagosDelTipo.reduce(0) { $0 + $1.monto }
            
            // Pre-calcular porcentaje
            let porcentaje = total > 0 ? (montoTipo / total) : 0
            
            let montoString = Formatters.money(montoTipo)
            let porcentajeString = String(format: "%.1f%%", porcentaje * 100)
            
            return IngresoUIModel(
                id: tipo,
                tipo: tipo.descripcion,
                rawMonto: montoTipo,
                montoFormateado: montoString,
                porcentajeFormateado: "(\(porcentajeString))",
                color: tipo
            )
        }
        
        // 4. Ordenar y asignar
        self.ingresosUI = uiModels.sorted(by: { $0.rawMonto > $1.rawMonto })
        
        // Nota: Ya no necesitas la variable 'ingresosPorTipo' antigua si solo se usaba para el gráfico.
    }
    
    private func calcularKPIDeuda(deudores: [DeudorItem]) {
        self.totalDeuda = deudores.reduce(0) { $0 + $1.montoAdeudado }
    }
   
    private func fetchProximaActividadYGrafico() async throws {
        // 1. Buscamos cuál es el próximo curso (esto sigue siendo one-shot por ahora)
        let proximos = try await repository.fetchCursosProximos()
        
        // Filtramos para buscar Taller o Presencial
        let proxima = proximos.first(where: { $0.cursoTipo == .taller || $0.cursoTipo == .presencial })
        
        await MainActor.run {
            self.proximaActividad = proxima
        }
        
        // 2. Si encontramos actividad, nos SUSCRIBIMOS a sus cambios (Real-Time)
        if let actividad = proxima, let actividadID = actividad.id {
            subscribeToInscripciones(actividadID: actividadID, tipo: actividad.cursoTipo)
        } else {
            // Si no hay actividad, limpiamos datos
            await MainActor.run {
                self.inscripcionesProximaActividad = []
                self.ocupacionTaller = []
            }
        }
    }

        // Nueva función privada para manejar la suscripción
    private func subscribeToInscripciones(actividadID: String, tipo: TipoCurso) {
        // Limpiamos listener anterior si cambiamos de actividad
        inscripcionesListener?.remove()
        
        inscripcionesListener = repository.listenToInscripciones(cronogramaID: actividadID) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let inscripciones):
                // A. Actualizamos la lista bruta (esto arregla el contador de inscriptos)
                // Aunque no tengan hora, se contarán aquí.
                self.inscripcionesProximaActividad = inscripciones
                
                // B. Calculamos el gráfico SOLO si es Taller
                if tipo == .taller {
                    // Filtramos: Solo pasamos a la calculadora los que tienen hora válida
                    // Esto evita que el gráfico rompa o quede vacío si falta algún dato.
                    let inscriptosConHora = inscripciones.filter { $0.horario_inicio != nil }
                    
                    self.ocupacionTaller = TallerCalculator.calcularOcupacionPorHora(para: inscriptosConHora)
                } else {
                    self.ocupacionTaller = []
                }
                
            case .failure(let error):
                print("Error escuchando inscripciones: \(error.localizedDescription)")
            }
        }
    }
   
}
