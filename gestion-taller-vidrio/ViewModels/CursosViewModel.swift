import Foundation
import Combine

@MainActor
class CursosViewModel: ObservableObject {

    @Published var cursos: [Curso] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let taskTracker = TaskTracker()
    private var cursosListener: SuscripcionActiva?

    private let repository: any TallerRepositorio

    init(repository: (any TallerRepositorio)? = nil) {
        self.repository = repository ?? TallerRepository()
        startListening()
    }

    isolated deinit {
        cursosListener?.remove()
    }

    func startListening() {
        isLoading = true
        errorMessage = nil
        cursosListener?.remove()

        cursosListener = repository.listenToCursos { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let cursos):
                self.cursos = cursos.sorted { $0.nombre < $1.nombre }
            case .failure(let error):
                self.errorMessage = "Error sincronizando cursos: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    func saveCurso(curso: Curso) async -> (cronogramas: Int, inscripciones: Int)? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await repository.saveCurso(curso: curso)
        } catch {
            self.errorMessage = "Error al guardar el curso: \(FirestoreManager.mensajeAmigable(error))"
            return nil
        }
    }

    func deleteCurso(at offsets: IndexSet) {
        let cursosABorrar = offsets.map { self.cursos[$0] }
        isLoading = true
        errorMessage = nil
        taskTracker.track(Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for curso in cursosABorrar {
                        group.addTask {
                            try await self.repository.deleteCurso(curso: curso)
                        }
                    }
                    try await group.waitForAll()
                }
            } catch {
                self.errorMessage = "Error al borrar el curso: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }

    func toggleVisibilidad(curso: Curso) {
        guard let id = curso.id else { return }
        let nuevoValor = !(curso.visible_en_agenda ?? true)
        taskTracker.track(Task {
            do {
                try await repository.actualizarVisibilidadCurso(cursoId: id, visible: nuevoValor)
                if let idx = self.cursos.firstIndex(where: { $0.id == id }) {
                    self.cursos[idx].visible_en_agenda = nuevoValor
                }
            } catch {
                self.errorMessage = "Error al actualizar visibilidad: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }
}
