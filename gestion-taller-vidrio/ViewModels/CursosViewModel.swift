//
//  CursosViewModel.swift
//  gestiontaller
//
//  Created by Victor Krongold on 13/11/2025.
//


import Foundation
import Combine

@MainActor
class CursosViewModel: ObservableObject {
    
    @Published var cursos: [Curso] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository = FirestoreTallerRepository.shared
    
    init() {
        fetchCursos()
    }
    
    /// Carga o recarga la lista de cursos desde Firestore.
    func fetchCursos() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Obtenemos los cursos
                let fetchedCursos = try await repository.fetchCursos()
                
                // 2. CORRECCIÓN: Ordenamos la lista por nombre antes de publicarla
                self.cursos = fetchedCursos.sorted { $0.nombre < $1.nombre }
                
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al cargar cursos: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Guarda un curso (sea nuevo o existente) en Firestore.
    func saveCurso(curso: Curso) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await repository.saveCurso(curso: curso) // [cite: 241]
                self.fetchCursos() // Recargamos
            } catch {
                self.errorMessage = "Error al guardar el curso: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Borra los cursos en los índices seleccionados (para swipe-to-delete).
    func deleteCurso(at offsets: IndexSet) {
        let cursosABorrar = offsets.map { self.cursos[$0] }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for curso in cursosABorrar {
                        group.addTask {
                            try await self.repository.deleteCurso(curso: curso) // [cite: 241]
                        }
                    }
                    try await group.waitForAll()
                }
                
                self.fetchCursos() // Recargamos
                
            } catch {
                self.errorMessage = "Error al borrar el curso: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
