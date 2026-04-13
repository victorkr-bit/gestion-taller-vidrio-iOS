import Foundation
import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
class PedidosViewModel: ObservableObject {
    
    // MARK: - Estado de Datos
    @Published var pedidos: [Pedido] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Estado de UI (Buscador y Filtros)
    @Published var searchText: String = ""
    @Published var filtroPagoSeleccionado: FiltroEstadoPago = .todos
    // AGREGADO: Estado para el filtro de entregas
    @Published var filtroEntregaSeleccionado: FiltroEstadoEntrega = .pendientes    
    // Caché de pagos
    @Published var pagosPorPedido: [String: [Pago]] = [:]
    
    // Almacén de Listeners
    private var pedidosListener: ListenerRegistration?
    private var paymentListeners: [String: ListenerRegistration] = [:]
    private let taskTracker = TaskTracker()
    
    // MARK: - Enums de Filtros
    
    enum FiltroEstadoPago: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case pagados = "Pagados"
        case pendientes = "Pendientes"
        var id: String { rawValue }
    }
    
    // AGREGADO: Enum para filtro de entregas
    enum FiltroEstadoEntrega: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case entregados = "Entregados"
        case pendientes = "Pendientes"
        var id: String { rawValue }
    }
    
    // MARK: - Propiedad Computada (Lógica de Filtrado Completa)
    var pedidosVisibles: [Pedido] {
        // 1. Filtrar por Texto
        let filtradosPorTexto: [Pedido]
        if searchText.isEmpty {
            filtradosPorTexto = pedidos
        } else {
            filtradosPorTexto = pedidos.filter { pedido in
                let textoBusqueda = searchText.lowercased()
                return pedido.cliente_nombre.lowercased().contains(textoBusqueda) ||
                       pedido.descripcion.lowercased().contains(textoBusqueda) ||
                       pedido.numero_pedido.lowercased().contains(textoBusqueda)
            }
        }
        
        // 2. Filtrar por Estado de Pago
        let filtradosPorPago: [Pedido]
        switch filtroPagoSeleccionado {
        case .todos:
            filtradosPorPago = filtradosPorTexto
        case .pagados:
            filtradosPorPago = filtradosPorTexto.filter { $0.estado_pago && $0.presupuesto > 0 }
        case .pendientes:
            filtradosPorPago = filtradosPorTexto.filter { !$0.estado_pago || $0.presupuesto == 0 }
        }
        
        // 3. Filtrar por Estado de Entrega (AGREGADO)
        switch filtroEntregaSeleccionado {
        case .todos:
            return filtradosPorPago
        case .entregados:
            return filtradosPorPago.filter { $0.estado_entrega }
        case .pendientes:
            return filtradosPorPago.filter { !$0.estado_entrega }
        }
    }
    
    // MARK: - Inyección de Dependencias
    
    private let ventasRepo: VentasRepository
    private let finanzasRepo: FinanzasRepository
    
    // Inicializador con Instanciación Perezosa
    init(ventasRepo: VentasRepository? = nil, finanzasRepo: FinanzasRepository? = nil) {
        self.ventasRepo = ventasRepo ?? VentasRepository()
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        startListeningOrders()
    }
    
    deinit {
        taskTracker.cancelAll()
        pedidosListener?.remove()
        paymentListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Factory

    func makePedidoFormViewModel(pedido: Pedido? = nil) -> PedidoFormViewModel {
        PedidoFormViewModel(pedido: pedido, repository: ventasRepo)
    }

    // MARK: - Gestión de Pedidos (VentasRepository)
    
    func startListeningOrders() {
        isLoading = true
        errorMessage = nil
        
        pedidosListener?.remove()
        
        pedidosListener = ventasRepo.listenToPedidos { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let pedidos):
                self.pedidos = pedidos
            case .failure(let error):
                self.errorMessage = "Error sincronizando pedidos: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        }
    }
    
    func deletePedido(_ pedido: Pedido) {
        guard pedido.monto_abonado == 0 else {
            errorMessage = "No se puede eliminar el pedido porque tiene pagos registrados. Eliminá los pagos primero."
            return
        }

        if let index = pedidos.firstIndex(where: { $0.id == pedido.id }) {
            withAnimation {
                _ = pedidos.remove(at: index)
            }
        }

        taskTracker.track(Task {
            do {
                try await ventasRepo.deletePedido(pedido: pedido)
            } catch {
                self.errorMessage = "No se pudo eliminar el pedido: \(FirestoreManager.mensajeAmigable(error))"
                self.startListeningOrders()
            }
        })
    }
    
    // MARK: - Gestión de Pagos (FinanzasRepository)
    
    func fetchPagos(para pedido: Pedido) {
        guard let id = pedido.id else { return }
        if paymentListeners[id] != nil { return }
        
        if pagosPorPedido[id] == nil {
            pagosPorPedido[id] = []
        }
        
        let listener = finanzasRepo.listenToPagos(origenID: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pagos):
                withAnimation {
                    self.pagosPorPedido[id] = pagos
                }
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
        paymentListeners[id] = listener
    }
    
    func stopListeningPagos(para pedido: Pedido) {
        guard let id = pedido.id else { return }
        paymentListeners[id]?.remove()
        paymentListeners[id] = nil
    }

    func cleanupPaymentListeners() {
        paymentListeners.values.forEach { $0.remove() }
        paymentListeners.removeAll()
        pagosPorPedido.removeAll()
    }
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        try await finanzasRepo.registrarPago(pago: pago, origen: origen)
    }
    
    func deletePago(_ pago: Pago) {
        taskTracker.track(Task {
            do {
                try await finanzasRepo.deletePago(pago: pago)
            } catch {
                self.errorMessage = "Error al borrar pago: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }
}
