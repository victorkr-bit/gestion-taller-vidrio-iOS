import Foundation
import Combine

@MainActor
class ContactosViewModel: ObservableObject {
    
    @Published var contactos: [Contacto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // --- NUEVO: Estado para el texto del buscador ---
    @Published var searchText: String = ""

    private let taskTracker = TaskTracker()
    private let repository: VentasRepository
    
    // --- NUEVO: Lista Computada ---
    // La vista observará ESTA lista, no la original 'contactos'
    var contactosFiltrados: [Contacto] {
        if searchText.isEmpty {
            return contactos
        } else {
            return contactos.filter { contacto in
                // Buscamos por nombre (insensible a mayúsculas/minúsculas)
                // Podrías agregar "|| contacto.telefono.contains..." si quisieras
                contacto.nombreCompleto.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // CAMBIO 2: Inicializador con valor por defecto
    
    init(repository: VentasRepository? = nil) {
        self.repository = repository ?? VentasRepository()
        fetchContactos()
    }

    deinit {
        taskTracker.cancelAll()
    }

    func fetchContactos() {
        isLoading = true
        errorMessage = nil
        
        taskTracker.track(Task {
            do {
                let fetchedContactos = try await repository.fetchContactos(forceRefresh: true)
                self.contactos = fetchedContactos.sorted { $0.nombreCompleto < $1.nombreCompleto }
                self.isLoading = false // Se me pasó a false aquí
            } catch {
                self.errorMessage = "Error al cargar contactos: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }

    func saveContacto(datos: Contacto, id: String) {
        taskTracker.track(Task {
            do {
                try await saveContactoAsync(datos: datos, id: id)
            } catch {
                self.errorMessage = "Error al guardar contacto: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func saveContactoAsync(datos: Contacto, id: String) async throws {
        try await repository.saveContacto(datos, uid: id)
        fetchContactos()
    }

    func updateContactoAsync(datos: Contacto, id: String) async throws {
        try await repository.updateContacto(datos, id: id)
        fetchContactos()
    }
    
    // --- MODIFICADO: Borrado Seguro con Filtros ---
    func deleteContacto(at offsets: IndexSet) {
        // ¡OJO AQUÍ! Usamos 'contactosFiltrados' para saber a quién borrar,
        // porque el usuario está viendo e interactuando con la lista filtrada.
        let contactosABorrar = offsets.map { self.contactosFiltrados[$0] }
        
        isLoading = true
        errorMessage = nil
        
        taskTracker.track(Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for contacto in contactosABorrar {
                        group.addTask {
                            try await self.repository.deleteContacto(contacto: contacto)
                        }
                    }
                    try await group.waitForAll()
                }
                
                // Recargamos la lista post-borrado
                self.fetchContactos()
                
            } catch {
                self.errorMessage = "Error al borrar el contacto: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }
}

