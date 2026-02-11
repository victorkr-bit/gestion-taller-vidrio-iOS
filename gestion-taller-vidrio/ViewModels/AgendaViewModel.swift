import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class AgendaViewModel: ObservableObject {

    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Lógica de Filtro
    @Published private var cursosProximos: [CronogramaItem] = []
    @Published private var cursosHistoricos: [CronogramaItem] = []

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

    // Catálogo de cursos (para picker en CronogramaFormView)
    @Published var cursos: [Curso] = []

    // Listener
    private var cronogramaListener: ListenerRegistration?

    // MARK: - Dependencia
    private let tallerRepo: TallerRepository

    init(tallerRepo: TallerRepository) {
        self.tallerRepo = tallerRepo
        subscribeToCronograma()
        fetchCronograma()
    }

    deinit {
        cronogramaListener?.remove()
    }

    // MARK: - Lógica Reactiva

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
                self.isLoading = false
            }
        }
    }

    func fetchCronograma() {
        // Recarga manual del historial
        Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch {
                self.errorMessage = "Error actualizando historial: \(error.localizedDescription)"
            }
        }
    }

    func fetchCursos() {
        Task {
            do {
                self.cursos = try await tallerRepo.fetchCursos()
            } catch {
                self.errorMessage = "Error al cargar el catálogo de cursos: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - CRUD Cronograma

    func saveCronogramaItem(item: CronogramaItem) {
        Task {
            do {
                try await tallerRepo.saveCronogramaItem(item: item)
            } catch {
                self.errorMessage = "Error al guardar el curso programado: \(error.localizedDescription)"
            }
        }
    }

    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?) async throws {
        errorMessage = nil
        try await tallerRepo.actualizarCronograma(id: id, nuevoPrecio: nuevoPrecio, nuevaFecha: nuevaFecha)
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
}
