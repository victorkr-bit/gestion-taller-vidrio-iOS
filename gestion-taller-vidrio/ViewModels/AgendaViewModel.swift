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
    @Published private(set) var cursosProximos: [CronogramaItem] = []
    @Published private(set) var cursosHistoricos: [CronogramaItem] = []

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

    // Catálogo de cursos (para picker en AgendaFormView)
    @Published var cursos: [Curso] = []

    // Listener
    private var cronogramaListener: ListenerRegistration?
    private let taskTracker = TaskTracker()

    // MARK: - Dependencia
    private let tallerRepo: TallerRepository

    init(tallerRepo: TallerRepository) {
        self.tallerRepo = tallerRepo
        subscribeToCronograma()
    }

    isolated deinit {
        taskTracker.cancelAll()
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
                self.errorMessage = "Error sincronizando cronograma: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        }

        // Fetch de HISTORIAL (One-Shot)
        taskTracker.track(Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error cargando historial: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }

    func fetchCronograma() {
        // Recarga manual del historial
        taskTracker.track(Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error actualizando historial: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func fetchCursos() {
        taskTracker.track(Task {
            do {
                self.cursos = try await tallerRepo.fetchCursos()
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error al cargar el catálogo de cursos: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    // MARK: - CRUD Cronograma

    func saveCronogramaItem(item: CronogramaItem) {
        taskTracker.track(Task {
            do {
                try await tallerRepo.saveCronogramaItem(item: item)
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error al guardar el curso programado: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func item(for id: String) -> CronogramaItem? {
        cursosProximos.first { $0.id == id } ?? cursosHistoricos.first { $0.id == id }
    }

    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?) async throws {
        errorMessage = nil
        try await tallerRepo.actualizarCronograma(id: id, nuevoPrecio: nuevoPrecio, nuevaFecha: nuevaFecha, nuevasNotas: nuevasNotas)

        // Actualización local inmediata para que la UI refleje los cambios
        // sin esperar al listener (que además no cubre históricos).
        let aplicar = { (item: inout CronogramaItem) in
            if let precio = nuevoPrecio { item.precio_curso = precio }
            if let fecha = nuevaFecha { item.fecha = fecha }
            if let notas = nuevasNotas { item.notas = notas }
        }
        if let idx = cursosProximos.firstIndex(where: { $0.id == id }) {
            aplicar(&cursosProximos[idx])
        }
        if let idx = cursosHistoricos.firstIndex(where: { $0.id == id }) {
            aplicar(&cursosHistoricos[idx])
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
        taskTracker.track(Task {
            do {
                try await tallerRepo.deleteCronogramaItem(item: item)
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                // Rollback: re-suscribir restaura ambas listas desde el servidor
                self.subscribeToCronograma()
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        })
    }
}
