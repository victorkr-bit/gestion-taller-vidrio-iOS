import Foundation
import Combine

@MainActor
class PedidoFormViewModel: ObservableObject {
    
    // (Propiedades @Published siguen igual...)
    @Published var clienteId: String = ""
    @Published var clienteNombre: String = ""
    @Published var descripcion: String = ""
    @Published var presupuesto: Double = 0.0
    @Published var tipo: TipoPedido = .otros
    @Published var fecha: Date = Date()
    @Published var estadoEntrega: Bool = false
    @Published var montoAbonadoOriginal: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shouldDismiss: Bool = false
    @Published var contactos: [Contacto] = []
    
    private var activeTasks: [Task<Void, Never>] = []

    deinit {
        activeTasks.forEach { $0.cancel() }
    }

    // CAMBIO 1: Repo de Ventas
    private let repository: VentasRepository
    private let editingPedidoID: String?

    // CAMBIO 2: Init actualizado
    // Notar que 'pedido' es opcional, repository tiene valor por defecto
    init(pedido: Pedido? = nil, repository: VentasRepository? = nil) {
        self.repository = repository ?? VentasRepository()
        
        if let p = pedido {
            self.editingPedidoID = p.id
            self.clienteId = p.cliente_id
            self.clienteNombre = p.cliente_nombre
            self.descripcion = p.descripcion
            self.presupuesto = p.presupuesto
            self.tipo = p.tipo
            self.fecha = p.fecha
            self.estadoEntrega = p.estado_entrega
            self.montoAbonadoOriginal = p.monto_abonado
        } else {
            self.editingPedidoID = nil
            self.fecha = Date()
            self.tipo = .otros
        }
    }
    
    // (Propiedades computadas isValid, isEditing siguen igual...)
    var isValid: Bool {
        !clienteId.isEmpty && !descripcion.trimmingCharacters(in: .whitespaces).isEmpty && presupuesto >= 0
    }
    var isEditing: Bool { editingPedidoID != nil }

    func fetchContactos() {
        activeTasks.append(Task {
            do {
                self.contactos = try await repository.fetchContactos()
            } catch {
                self.errorMessage = "Error cargando contactos: \(error.localizedDescription)"
            }
        })
    }

    func guardar() {
        guard isValid else { return }
        self.isLoading = true
        
        activeTasks.append(Task {
            do {
                let pedido = Pedido(
                    id: nil,
                    numero_pedido: "",
                    cliente_id: self.clienteId,
                    cliente_nombre: self.clienteNombre,
                    presupuesto: self.presupuesto,
                    monto_abonado: 0,
                    monto_adeudado: 0,
                    estado_pago: false,
                    fecha: self.fecha,
                    descripcion: self.descripcion.trimmingCharacters(in: .whitespaces),
                    tipo: self.tipo,
                    estado_entrega: self.estadoEntrega
                )

                // Aquí llamamos al nuevo repo
                try await repository.savePedido(pedido: pedido, existingID: self.editingPedidoID)

                self.shouldDismiss = true
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        })
    }
}
