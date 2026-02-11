import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class CronogramaViewModel: ObservableObject {
    
    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Lógica de Filtro
    @Published private var cursosProximos: [CronogramaItem] = []
    @Published private var cursosHistoricos: [CronogramaItem] = []
    
    // Lógica de Formulario
    @Published var cursos: [Curso] = []
    
    // Lista principal de inscripciones
    @Published var inscripciones: [Inscripcion] = []
    
    // Caché de Pagos por Inscripción (Acordeón)
    @Published var pagosPorInscripcion: [String: [Pago]] = [:]
    
    @Published var ocupacionPorInscripcion: [String: Int] = [:]
    
    // MARK: - Estado Bimodal
    enum ModoVista: String, CaseIterable, Identifiable {
        case agenda = "Agenda"
        case online = "Cursos Online"
        var id: String { self.rawValue }
    }
        
    @Published var modoVista: ModoVista = .agenda
    @Published var catalogoOnline: [Curso] = []
    
    var mostrarFiltroHistorial: Bool { return modoVista == .agenda }
    
    // Almacén de Listeners activos
    private var paymentListeners: [String: ListenerRegistration] = [:]
    private var inscripcionesListener: ListenerRegistration?
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
        case .proximos: return cursosProximos
        case .historial: return cursosHistoricos
        }
    }
    
    // MARK: - Inyección de Dependencias (Híbrido)
    
    private let tallerRepo: TallerRepository
    private let finanzasRepo: FinanzasRepository
    let ventasRepo: VentasRepository

    init(tallerRepo: TallerRepository? = nil, finanzasRepo: FinanzasRepository? = nil, ventasRepo: VentasRepository? = nil) {
        self.tallerRepo = tallerRepo ?? TallerRepository()
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        self.ventasRepo = ventasRepo ?? VentasRepository()
        
        // Iniciar la escucha
        subscribeToCronograma()
        fetchCronograma() // Carga inicial del historial
    }
    
    deinit {
        paymentListeners.values.forEach { $0.remove() }
        inscripcionesListener?.remove()
        cronogramaListener?.remove()
        catalogoListener?.remove()
    }
    
    // MARK: - Lógica Reactiva (TallerRepository)
        
    func subscribeToCronograma() {
        isLoading = true
        errorMessage = nil
        
        cronogramaListener?.remove()
        
        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let items):
                self.cursosProximos = items
            case .failure(let error):
                self.errorMessage = "Error sincronizando cronograma: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
        
        // Fetch de HISTORIAL (One-Shot)
        Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch {
                self.errorMessage = "Error cargando historial: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchCronograma() {
        // Recarga manual del historial
        Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch {
                self.errorMessage = "Error actualizando historial."
            }
        }
    }
    
    func fetchCursos() {
        Task {
            do {
                self.cursos = try await tallerRepo.fetchCursos()
            } catch {
                self.errorMessage = "Error al cargar el catálogo de cursos."
            }
        }
    }
    
    // MARK: - Lógica Online (TallerRepository)
        
    func subscribeToCatalogoOnline() {
        isLoading = true
        errorMessage = nil
        catalogoListener?.remove()
        
        catalogoListener = tallerRepo.listenToCatalogoOnline { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let cursos):
                self.catalogoOnline = cursos.sorted { $0.nombre < $1.nombre }
            case .failure(let error):
                self.errorMessage = "Error sincronizando catálogo: \(error.localizedDescription)"
            }
        }
    }
    
    func saveCronogramaItem(item: CronogramaItem) {
        Task {
            do {
                try await tallerRepo.saveCronogramaItem(item: item)
            } catch {
                self.errorMessage = "Error al guardar el curso programado."
            }
        }
    }

    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?) async throws {
        errorMessage = nil
        try await tallerRepo.actualizarCronograma(id: id, nuevoPrecio: nuevoPrecio, nuevaFecha: nuevaFecha)
    }

    // MARK: - Lógica de Inscripciones (TallerRepository)
    
    func fetchInscripciones(cronogramaID: String) {
        isLoading = true
        errorMessage = nil
        inscripcionesListener?.remove()
        
        inscripcionesListener = tallerRepo.listenToInscripciones(cronogramaID: cronogramaID) { [weak self] result in
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

    func fetchInscripcionesOnline(cursoID: String) {
        isLoading = true
        errorMessage = nil
        inscripcionesListener?.remove()
        
        inscripcionesListener = tallerRepo.listenToInscripcionesOnline(cursoID: cursoID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let lista):
                self.inscripciones = lista
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
        Task {
            do {
                try await tallerRepo.saveInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = "Error al guardar la inscripción: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteCronogramaItem(_ item: CronogramaItem) {
        // 1. Validación client-side: evita el round-trip al servidor
        if item.inscriptosReales > 0 {
            self.errorMessage = "No se puede eliminar un curso con alumnos inscriptos. Eliminá las inscripciones primero."
            return
        }

        // 2. UI Optimista
        withAnimation {
            if let index = cursosProximos.firstIndex(where: { $0.id == item.id }) {
                cursosProximos.remove(at: index)
            }
            if let index = cursosHistoricos.firstIndex(where: { $0.id == item.id }) {
                cursosHistoricos.remove(at: index)
            }
        }

        // 3. Borrado real
        Task {
            do {
                try await tallerRepo.deleteCronogramaItem(item: item)
            } catch {
                // Rollback: re-suscribir restaura ambas listas desde el servidor
                self.subscribeToCronograma()
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func deleteInscripcion(_ inscripcion: Inscripcion) {
        Task {
            do {
                try await tallerRepo.deleteInscripcion(inscripcion: inscripcion)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Lógica de Pagos (FinanzasRepository)
    
    func fetchPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        if paymentListeners[id] != nil { return } // Ya estamos escuchando
        
        if pagosPorInscripcion[id] == nil {
            pagosPorInscripcion[id] = []
        }

        // Usamos el nuevo FinanzasRepo para escuchar cambios reales en los pagos
        let listener = finanzasRepo.listenToPagos(origenID: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosPorInscripcion[id] = pagos
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(error.localizedDescription)"
            }
        }
        
        paymentListeners[id] = listener
    }
    
    func stopListeningPagos(para inscripcion: Inscripcion) {
        guard let id = inscripcion.id else { return }
        paymentListeners[id]?.remove()
        paymentListeners[id] = nil
    }
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        try await finanzasRepo.registrarPago(pago: pago, origen: origen)
    }
}
