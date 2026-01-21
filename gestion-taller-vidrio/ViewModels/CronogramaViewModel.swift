import Foundation
import Combine
import SwiftUI
import FirebaseFirestore // Necesario para ListenerRegistration

@MainActor
class CronogramaViewModel: ObservableObject {
    
    // MARK: - Estado de la Vista
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // --- Lógica de Filtro (Fase 5) ---
    @Published private var cursosProximos: [CronogramaItem] = []
    @Published private var cursosHistoricos: [CronogramaItem] = []
    
    // --- Lógica de Formulario ---
    @Published var cursos: [Curso] = []
    
    // Lista principal de inscripciones
    @Published var inscripciones: [Inscripcion] = []
    
    // Caché de Pagos por Inscripción (Acordeón)
    @Published var pagosPorInscripcion: [String: [Pago]] = [:]
    
    @Published var ocupacionPorInscripcion: [String: Int] = [:]
    
    // MARK: - Estado Bimodal (Fase 3)
        
    enum ModoVista: String, CaseIterable, Identifiable {
        case agenda = "Agenda"
        case online = "Cursos Online"
        var id: String { self.rawValue }
    }
        
    @Published var modoVista: ModoVista = .agenda
    
    // Almacén de datos para el modo Online
    @Published var catalogoOnline: [Curso] = []
    
    // Computed property para saber si debo mostrar el filtro de historial
    var mostrarFiltroHistorial: Bool {
        return modoVista == .agenda
    }
    
    // NUEVO: Almacén de Listeners activos
    // Guardamos un listener por cada ID de inscripción que esté "expandida"
    private var paymentListeners: [String: ListenerRegistration] = [:]
    
    // NUEVO: Listener para las inscripciones (para que se actualice el estado "Pagado/Debe" en tiempo real)
    private var inscripcionesListener: ListenerRegistration?
    
    // NUEVO: Listener para la lista principal
    private var cronogramaListener: ListenerRegistration?
    
    private var catalogoListener: ListenerRegistration?
    
    enum FiltroCronograma: String, CaseIterable, Identifiable {
        case proximos = "Próximos"
        case historial = "Historial"
        var id: String { self.rawValue }
    }
    
    @Published var filtroSeleccionado: FiltroCronograma = .proximos
    
    var cursosFiltrados: [CronogramaItem] {
        switch filtroSeleccionado {
        case .proximos:
            return cursosProximos
        case .historial:
            return cursosHistoricos
        }
    }
    
    // MARK: - Dependencias
    
    private let repository = FirestoreTallerRepository.shared
    
    // MARK: - Inicializador
    
    init() {
        // 1. IMPORTANTE: Iniciar la escucha en tiempo real de los cursos próximos
        subscribeToCronograma()
        fetchCronograma()
        
    }
    
    // Limpieza al destruir el ViewModel (buena práctica)
    deinit {
        paymentListeners.values.forEach { $0.remove() }
        inscripcionesListener?.remove()
        cronogramaListener?.remove() // <--- Limpieza importante
        catalogoListener?.remove()
    }
    
    // MARK: - Lógica Reactiva (Real-Time)
        
    func subscribeToCronograma() {
        isLoading = true
        errorMessage = nil
        
        // 1. Suscripción a cursos PRÓXIMOS (Donde ocurre la acción)
        // Si ya existía, lo removemos para no duplicar
        cronogramaListener?.remove()
        
        cronogramaListener = repository.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }
            
            // Apagamos loading tras recibir el primer snapshot
            self.isLoading = false
            
            switch result {
            case .success(let items):
                self.cursosProximos = items
            case .failure(let error):
                self.errorMessage = "Error sincronizando cronograma: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
        
        // 2. Fetch de HISTORIAL (Lo mantenemos "One-Shot" por eficiencia)
        // Rara vez cambian los inscriptos de cursos pasados.
        Task {
            do {
                self.cursosHistoricos = try await repository.fetchCursosHistoricos()
            } catch {
                print("Error cargando historial: \(error)")
                // No bloqueamos la UI por esto, es secundario
            }
        }
    }
    
    // MARK: - Intenciones (Lógica de UI)
    
    // Reemplaza a tu antiguo fetchCronograma
    func fetchCronograma() {
        // En un esquema Real-time, "fetch" suele significar "reconectar" o "forzar refresh del historial"
        // Como el listener de próximos es automático, aquí solo recargamos el historial.
        Task {
            do {
                self.cursosHistoricos = try await repository.fetchCursosHistoricos()
            } catch {
                self.errorMessage = "Error actualizando historial."
            }
        }
    }
    
    func fetchCursos() {
        Task {
            do {
                self.cursos = try await repository.fetchCursos()
            } catch {
                self.errorMessage = "Error al cargar el catálogo de cursos."
            }
        }
    }
    
    // MARK: - Lógica Online (Evergreen)
        
    func subscribeToCatalogoOnline() {
        isLoading = true
        errorMessage = nil
        
        // 1. Limpieza preventiva: Si ya escuchábamos, cancelamos para no duplicar.
        catalogoListener?.remove()
        
        // 2. Iniciamos la escucha
        catalogoListener = repository.listenToCatalogoOnline { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let cursos):
                // Ordenamos aquí en memoria
                self.catalogoOnline = cursos.sorted { $0.nombre < $1.nombre }
                
            case .failure(let error):
                self.errorMessage = "Error sincronizando catálogo: \(error.localizedDescription)"
            }
        }
    }
    
    
    func saveCronogramaItem(item: CronogramaItem) {
        // Ya no necesitamos isLoading manual para la lista, el listener reaccionará.
        Task {
            do {
                try await repository.saveCronogramaItem(item: item)
                // NO llamamos fetchCronograma(), el listener actualizará la UI solo.
            } catch {
                self.errorMessage = "Error al guardar el curso programado."
            }
        }
    }

    // MARK: - Lógica de Inscripciones (AHORA EN TIEMPO REAL)
    
    /// Activa un listener para ver las inscripciones de un cronograma en tiempo real.
    /// Esto asegura que si pagas y cambia el saldo, la tarjetita se pinte de verde sola.
    func fetchInscripciones(cronogramaID: String) {
        isLoading = true
        errorMessage = nil
        
        // 1. Cancelamos listener anterior si existía (para no superponer escuchas)
        inscripcionesListener?.remove()
        
        // 2. Activamos el nuevo listener
        inscripcionesListener = repository.listenToInscripciones(cronogramaID: cronogramaID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let lista):
                self.inscripciones = lista
                self.calcularOcupaciones(para: lista)
            case .failure(let error):
                self.errorMessage = "Error en inscripciones: \(error.localizedDescription)"
            }
        }
    }

    /// Activa un listener para ver las inscripciones de un curso ONLINE (Evergreen).
    /// Aquí el ID es del PRODUCTO (Curso), no del evento.
    func fetchInscripcionesOnline(cursoID: String) {
        isLoading = true
        errorMessage = nil
        
        // 1. Cancelamos listener anterior para evitar fugas de memoria o datos cruzados
        inscripcionesListener?.remove()
        
        // 2. Activamos el nuevo listener específico para Online (creado en Fase 2)
        inscripcionesListener = repository.listenToInscripcionesOnline(cursoID: cursoID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let lista):
                self.inscripciones = lista
                // Nota: En online no solemos calcular ocupación de "asientos",
                // pero si quisieras métricas, irían aquí.
                // self.calcularOcupaciones(para: lista)
            case .failure(let error):
                self.errorMessage = "Error en inscripciones online: \(error.localizedDescription)"
            }
        }
    }
    
    private func calcularOcupaciones(para lista: [Inscripcion]) {
        var ocupaciones: [String: Int] = [:]
        for inscripcion in lista {
            guard let id = inscripcion.id else { continue }
            let ocupacion = TallerCalculator.calcularOcupacion(para: inscripcion, enLista: lista)
            ocupaciones[id] = ocupacion
        }
        self.ocupacionPorInscripcion = ocupaciones
    }
    
    func saveInscripcion(inscripcion: Inscripcion) {
        // Ya no necesitamos isLoading manual porque el listener refrescará la UI
        Task {
            do {
                try await repository.saveInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al guardar la inscripción: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteCronogramaItem(_ item: CronogramaItem) {
        // 1. UI OPTIMISTA: Borrar localmente INMEDIATAMENTE.
        // Esto satisface la animación de 'swipe-to-delete' de SwiftUI y evita el crash
        // por inconsistencia de número de filas.
        
        withAnimation {
            // Buscamos y borramos de la lista de Próximos
            if let index = cursosProximos.firstIndex(where: { $0.id == item.id }) {
                cursosProximos.remove(at: index)
            }
            
            // Buscamos y borramos de la lista de Historial
            if let index = cursosHistoricos.firstIndex(where: { $0.id == item.id }) {
                cursosHistoricos.remove(at: index)
            }
        }
        
        // 2. OPERACIÓN DE BACKEND
        // Hacemos la llamada real a Firestore en segundo plano.
        Task {
            do {
                try await repository.deleteCronogramaItem(item: item)
                // Éxito: No hacemos nada más, el listener se mantendrá sincronizado solo.
            } catch {
                // 3. ROLLBACK (Si falla el backend)
                // Si hubo un error real (ej. sin internet), mostramos alerta.
                // Idealmente deberíamos re-insertar el item, pero para simplificar,
                // forzamos una recarga para que vuelva a aparecer.
                self.errorMessage = "No se pudo borrar: \(error.localizedDescription)"
                self.fetchCronograma() // Recarga de seguridad
            }
        }
    }
    
    func deleteInscripcion(_ inscripcion: Inscripcion) {
        // isLoading gestionado por el listener
        Task {
            do {
                try await repository.deleteInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Lógica de Pagos (AHORA EN TIEMPO REAL PARA ACORDEÓN)
    
    /// Llamado cuando se expande el acordeón
    func fetchPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        
        // Si ya estamos escuchando este ID, no hacemos nada
        if paymentListeners[id] != nil { return }
        
        // Placeholder visual inmediato
        if pagosPorInscripcion[id] == nil {
            pagosPorInscripcion[id] = []
        }

        // Activamos un listener específico para los pagos de ESTA inscripción
        // OJO: Necesitas agregar una función `listenToPagos(origenID:)` en tu repositorio.
        // Si no la tienes, te paso el código abajo.
        // Por ahora, asumimos que usaremos la función de fetch normal pero en un polling o agregaremos el listener.
        
        // -- CORRECCIÓN: Para no obligarte a cambiar el Repo ahora mismo, simularemos el tiempo real
        // recargando cuando sepamos que hubo un cambio, pero lo IDEAL es un listener.
        
        // VAMOS A USAR UN LISTENER MANUAL AQUI.
        // Necesitamos acceso a Firestore directo o agregar la funcion al repo.
        // Agreguemos la función al repo es lo más limpio.
        
        // Asumiendo que agregaremos `listenToPagos(origenID: ...)` al repo:
        let listener = repository.listenToPagos(origenID: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosPorInscripcion[id] = pagos
            case .failure(let error):
                print("Error escuchando pagos: \(error)")
            }
        }
        
        // Guardamos el token para poder cancelarlo al colapsar
        paymentListeners[id] = listener
    }
    
    /// Llamado cuando se colapsa el acordeón (Optimización)
    func stopListeningPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        // 1. Cancelamos la escucha en Firebase
        paymentListeners[id]?.remove()
        // 2. Borramos el token
        paymentListeners[id] = nil
        // Opcional: Limpiar la memoria de pagos
        // pagosPorInscripcion[id] = nil
    }
    
    // MARK: - Acciones Financieras
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        
        // La actualización de la UI será automática gracias a los listeners
        try await repository.registrarPago(pago: pago, origen: origen)
    }
}
