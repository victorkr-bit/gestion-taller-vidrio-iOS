import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class PedidosViewModel: ObservableObject {
    
    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Fuente de la verdad (Datos crudos de Firebase)
    @Published private var pedidos: [Pedido] = []
    
    // Resultado Final (Lo que ve la UI tras filtrar)
    @Published var pedidosVisibles: [Pedido] = []
    
    // --- ESTADO PARA ACORDEÓN ---
    @Published var pagosPorPedido: [String: [Pago]] = [:]
    
    // Almacén de Listeners
    private var paymentListeners: [String: ListenerRegistration] = [:]
    private var ordersListener: ListenerRegistration?
    
    // --- Filtros de UI ---
    
    enum FiltroEstadoPago: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case pagados = "Pagados"
        case noPagados = "No Pagados"
        var id: String { self.rawValue }
    }
    
    enum FiltroEstadoEntrega: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case entregados = "Entregados"
        case pendientes = "Pendientes"
        var id: String { self.rawValue }
    }
    
    // Observamos cambios en los filtros para recalcular la lista
    @Published var filtroPagoSeleccionado: FiltroEstadoPago = .todos {
        didSet { aplicarFiltros() }
    }
    
    @Published var filtroEntregaSeleccionado: FiltroEstadoEntrega = .pendientes {
        didSet { aplicarFiltros() }
    }
    
    // Nuevo: Búsqueda centralizada en el VM
    var searchText: String = "" {
        didSet { aplicarFiltros() }
    }
    
    // MARK: - Lógica Centralizada de Filtrado
    
    private func aplicarFiltros() {
        var resultado = pedidos
        
        // 1. Filtro de Pago
        switch filtroPagoSeleccionado {
        case .todos:
            break
        case .pagados:
            resultado = resultado.filter { $0.estado_pago == true }
        case .noPagados:
            resultado = resultado.filter { $0.estado_pago == false }
        }
        
        // 2. Filtro de Entrega
        switch filtroEntregaSeleccionado {
        case .todos:
            break
        case .entregados:
            resultado = resultado.filter { $0.estado_entrega == true }
        case .pendientes:
            resultado = resultado.filter { $0.estado_entrega == false }
        }
        
        // 3. Filtro de Texto (Búsqueda)
        if !searchText.isEmpty {
            resultado = resultado.filter { pedido in
                let matchNombre = pedido.cliente_nombre.localizedCaseInsensitiveContains(searchText)
                let matchNumero = pedido.numero_pedido.localizedCaseInsensitiveContains(searchText)
                let matchDesc = pedido.descripcion.localizedCaseInsensitiveContains(searchText)
                let matchTipo = pedido.tipo.rawValue.localizedCaseInsensitiveContains(searchText)
                return matchNombre || matchNumero || matchDesc || matchTipo
            }
        }
        
        // 4. Ordenamiento y Asignación Final
        self.pedidosVisibles = resultado.sorted(by: { $0.numero_pedido > $1.numero_pedido })
    }
    
    // MARK: - Dependencias
    private let repository = FirestoreTallerRepository.shared
    
    // MARK: - Init
    init() {
        startListeningOrders()
    }
    
    deinit {
        ordersListener?.remove()
        paymentListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Lógica de Firebase
    
    func startListeningOrders() {
        isLoading = true
        errorMessage = nil
        
        ordersListener?.remove()
        
        ordersListener = repository.listenToPedidos { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let pedidosActualizados):
                self.pedidos = pedidosActualizados
                // Importante: Al recibir nuevos datos, reaplicamos filtros
                self.aplicarFiltros()
                
            case .failure(let error):
                self.errorMessage = "Error de conexión: \(error.localizedDescription)"
            }
        }
    }
    
    func deletePedido(_ pedido: Pedido) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await repository.deletePedido(pedido: pedido)
                // No hace falta actualizar localmente, el listener lo hará
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Lógica de Pagos en Tiempo Real (Acordeón)
    
    func fetchPagos(para pedido: Pedido) {
        guard let id = pedido.id else { return }
        if paymentListeners[id] != nil { return }
        
        if pagosPorPedido[id] == nil {
            pagosPorPedido[id] = []
        }
        
        let listener = repository.listenToPagos(origenID: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                self.pagosPorPedido[id] = pagos
            case .failure(let error):
                print("Error escuchando pagos del pedido \(id): \(error)")
            }
        }
        
        paymentListeners[id] = listener
    }
    
    func stopListeningPagos(para pedido: Pedido) {
        guard let id = pedido.id else { return }
        paymentListeners[id]?.remove()
        paymentListeners[id] = nil
    }
    
    // MARK: - Registro de Pagos
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        try await repository.registrarPago(pago: pago, origen: origen)
    }
}
