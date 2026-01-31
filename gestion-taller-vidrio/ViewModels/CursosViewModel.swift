import Foundation
import Combine

@MainActor
class CursosViewModel: ObservableObject {
    
    @Published var cursos: [Curso] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // CAMBIO 1: Repo específico
    private let repository: TallerRepository
    
    // CAMBIO 2: Init
    init(repository: TallerRepository? = nil) {
        self.repository = repository ?? TallerRepository()
        fetchCursos()
    }
    
    func fetchCursos() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedCursos = try await repository.fetchCursos()
                self.cursos = fetchedCursos.sorted { $0.nombre < $1.nombre }
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al cargar cursos: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func saveCurso(curso: Curso) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await repository.saveCurso(curso: curso)
                self.fetchCursos()
            } catch {
                self.errorMessage = "Error al guardar el curso: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func deleteCurso(at offsets: IndexSet) {
        let cursosABorrar = offsets.map { self.cursos[$0] }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for curso in cursosABorrar {
                        group.addTask {
                            try await self.repository.deleteCurso(curso: curso)
                        }
                    }
                    try await group.waitForAll()
                }
                self.fetchCursos()
            } catch {
                self.errorMessage = "Error al borrar el curso: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
