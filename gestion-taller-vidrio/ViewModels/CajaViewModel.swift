import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class CajaViewModel: ObservableObject {
    
    // MARK: - Estado de Datos (Backend)
    @Published var pagos: [Pago] = []
    @Published var contactos: [Contacto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Estado de UI (Buscador y Totales) -- AGREGADO
    @Published var searchText: String = ""
    
    /// Filtra los pagos locales por el texto de búsqueda
    var pagosFiltrados: [Pago] {
        if searchText.isEmpty {
            return pagos
        } else {
            return pagos.filter { pago in
                let query = searchText.lowercased()
                // Buscamos en Cliente, Descripción o Notas
                return pago.cliente_nombre.lowercased().contains(query) ||
                       pago.descripcion_origen.lowercased().contains(query) ||
                       (pago.notas ?? "").lowercased().contains(query)
            }
        }
    }
    
    /// Calcula el total de dinero visible en la lista filtrada
    var totalFiltrado: Double {
        return pagosFiltrados.reduce(0) { $0 + $1.monto }
    }
    
    // MARK: - Filtros de Fecha
    @Published var fechaInicio: Date = Date() {
        didSet { restartListener() }
    }
    
    @Published var fechaFin: Date = Date() {
        didSet { restartListener() }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    
    // MARK: - Inyección de Dependencias
    private let finanzasRepo: FinanzasRepository
    private let ventasRepo: VentasRepository
    
    // MARK: - Inicializador
    init(
        finanzasRepo: FinanzasRepository? = nil,
        ventasRepo: VentasRepository? = nil,
        fechaInicioPublisher: AnyPublisher<Date, Never>? = nil,
        fechaFinPublisher: AnyPublisher<Date, Never>? = nil
    ) {
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        self.ventasRepo = ventasRepo ?? VentasRepository()
        
        let calendar = Calendar.current
        self.fechaInicio = calendar.startOfDay(for: Date())
        self.fechaFin = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        
        // Conexión reactiva con el Dashboard
        if let startPub = fechaInicioPublisher, let endPub = fechaFinPublisher {
            Publishers.CombineLatest(startPub, endPub)
                .receive(on: RunLoop.main)
                .sink { [weak self] (inicio, fin) in
                    guard let self = self else { return }
                    if self.fechaInicio != inicio { self.fechaInicio = inicio }
                    if self.fechaFin != fin { self.fechaFin = fin }
                }
                .store(in: &cancellables)
        }
        
        restartListener()
        fetchContactos()
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
    
    // MARK: - Lógica de Caja
    
    func restartListener() {
        isLoading = true
        errorMessage = nil
        listener?.remove()
        
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: fechaFin) ?? fechaFin
        
        listener = finanzasRepo.listenToPagos(from: fechaInicio, to: endOfDay) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let pagosNuevos):
                self.pagos = pagosNuevos
            case .failure(let error):
                self.errorMessage = "Error sincronizando caja: \(error.localizedDescription)"
            }
        }
    }
    
    func deletePago(_ pago: Pago) {
        Task {
            do {
                try await finanzasRepo.deletePago(pago: pago)
            } catch {
                self.errorMessage = "No se pudo borrar el pago: \(error.localizedDescription)"
            }
        }
    }
    
    // Edición
    func savePagoEditado(pago: Pago, montoAntiguo: Double) {
        isLoading = true
        Task {
            do {
                try await finanzasRepo.editPago(pagoActualizado: pago, montoAntiguo: montoAntiguo)
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al editar pago: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        try await finanzasRepo.registrarPago(pago: pago, origen: origen)
    }
    
    // MARK: - Venta Directa
    
    func fetchContactos() {
        Task {
            do {
                self.contactos = try await ventasRepo.fetchContactos()
            } catch {
                print("Error cargando contactos: \(error)")
            }
        }
    }
    
    // Opción 1: Manual (Objeto completo)
    func saveVentaDirecta(pago: Pago) {
        Task {
            do {
                try await finanzasRepo.saveVentaDirecta(pago: pago)
            } catch {
                self.errorMessage = "Error guardando venta: \(error.localizedDescription)"
            }
        }
    }
    
    // Opción 2: Automática (Argumentos sueltos)
    func saveVentaDirecta(monto: Double, medioPago: MedioDePago, notas: String, cliente: Contacto?) {
        let nuevoPago = Pago(
            id: nil,
            fecha: Date(),
            monto: monto,
            medio_de_pago: medioPago,
            cliente_id: cliente?.id ?? "",
            cliente_nombre: cliente?.nombreCompleto ?? "Consumidor Final",
            tipo_venta: .otros,
            notas: notas,
            origen_tipo: .ventaDirecta,
            descripcion_origen: "Venta Directa",
            origen_id: nil
        )
        saveVentaDirecta(pago: nuevoPago)
    }
}
