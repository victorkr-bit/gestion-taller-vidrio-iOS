import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class CajaViewModel: ObservableObject {
    
    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // "Fuente de la Verdad": Todos los datos crudos de Firestore
    @Published private(set) var pagos: [Pago] = []
    
    // MARK: - Salidas para la UI (Outputs)
    
    // 1. Lista filtrada para iterar en la View
    @Published var filteredAndSearchedPagos: [Pago] = []
    
    // 2. El Total ya calculado (La View solo lo muestra)
    @Published var totalFiltrado: Double = 0.0
    
    @Published var contactos: [Contacto] = []
    
    // MARK: - Entradas (Inputs)
    
    // Fechas (Privadas, manejadas por el init y combine)
    private var fechaInicio: Date = Date()
    private var fechaFin: Date = Date()
    
    // Texto de Búsqueda: Reactivo (Al cambiar, se dispara el filtro)
    var searchText: String = "" {
        didSet { aplicarFiltros() }
    }
    
    // MARK: - Dependencias
    private let repository = FirestoreTallerRepository.shared
    private var cancellables = Set<AnyCancellable>()
    private var pagosListener: ListenerRegistration?
    
    // MARK: - Inicializador
    
    init(fechaInicioPublisher: AnyPublisher<Date, Never>,
         fechaFinPublisher: AnyPublisher<Date, Never>) {
        
        fetchContactos()
        
        // Escuchamos cambios en las fechas del Dashboard
        Publishers.CombineLatest(fechaInicioPublisher, fechaFinPublisher)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] (inicio, fin) in
                guard let self = self else { return }
                
                self.fechaInicio = inicio
                self.fechaFin = fin
                
                // Al cambiar fechas, recargamos la suscripción a Firebase
                self.subscribeToPagos()
            }
            .store(in: &cancellables)
    }
    
    // Init de conveniencia para pruebas
    convenience init() {
        let previewInicio = Just(Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()).eraseToAnyPublisher()
        let previewFin = Just(Date()).eraseToAnyPublisher()
        self.init(fechaInicioPublisher: previewInicio, fechaFinPublisher: previewFin)
    }
    
    deinit {
        pagosListener?.remove()
    }
    
    // MARK: - Lógica Real-time
    
    func subscribeToPagos() {
        isLoading = true
        errorMessage = nil
        
        pagosListener?.remove()
        
        pagosListener = repository.listenToPagos(from: fechaInicio, to: fechaFin) { [weak self] result in
            guard let self = self else { return }
            
            self.isLoading = false
            
            switch result {
            case .success(let pagosActualizados):
                // 1. Actualizamos fuente de verdad
                self.pagos = pagosActualizados
                
                // 2. Re-aplicamos filtros (para mantener la búsqueda si el usuario estaba escribiendo)
                self.aplicarFiltros()
                
            case .failure(let error):
                self.errorMessage = "Error en tiempo real: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchContactos() {
        Task {
            do {
                self.contactos = try await repository.fetchContactos()
            } catch {
                self.errorMessage = "Error al cargar contactos: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Lógica de Filtrado Centralizada
    
    private func aplicarFiltros() {
        // 1. Si no hay texto, mostramos todo
        if searchText.isEmpty {
            self.filteredAndSearchedPagos = self.pagos
        } else {
            // 2. Lógica de filtrado "AND" (debe contener todas las palabras)
            let terminos = searchText
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            
            self.filteredAndSearchedPagos = self.pagos.filter { pago in
                // Construimos el contenido buscable
                // Truco: Agregamos el monto como string para poder buscar "$1500"
                let contenidoBuscable = """
                    \(pago.cliente_nombre)
                    \(pago.descripcion_origen)
                    \(pago.medio_de_pago.rawValue)
                    \(pago.notas ?? "")
                    \(String(format: "%.0f", pago.monto))
                    """
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                
                return terminos.allSatisfy { termino in
                    contenidoBuscable.contains(termino)
                }
            }
        }
        
        // 3. CÁLCULO DEL TOTAL
        // El VM es responsable de sumar. La View solo muestra el número.
        self.totalFiltrado = self.filteredAndSearchedPagos.reduce(0) { $0 + $1.monto }
    }
    
    // MARK: - Acciones (CRUD)
    
    func deletePago(_ pago: Pago) {
        Task {
            do {
                try await repository.deletePago(pago: pago)
            } catch {
                self.errorMessage = "Error al borrar: \(error.localizedDescription)"
            }
        }
    }
    
    // Nota: El edit se suele hacer presentando un sheet,
    // pero si necesitas lógica de guardado aquí:
    func savePagoEditado(pago: Pago, montoAntiguo: Double) {
        Task {
            do {
                try await repository.editPago(pagoActualizado: pago, montoAntiguo: montoAntiguo)
            } catch {
                self.errorMessage = "Error al editar: \(error.localizedDescription)"
            }
        }
    }
    
    func saveVentaDirecta(pago: Pago) {
        Task {
            do {
                try await repository.saveVentaDirecta(pago: pago)
            } catch {
                self.errorMessage = "Error al guardar venta: \(error.localizedDescription)"
            }
        }
    }
}
