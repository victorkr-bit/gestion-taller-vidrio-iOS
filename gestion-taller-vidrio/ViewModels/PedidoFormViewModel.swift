//
//  PedidoFormViewModel.swift
//  gestion-taller-vidrio
//
//  Created by Victor Krongold on 13/12/2025.
//


import Foundation
import Combine

@MainActor
class PedidoFormViewModel: ObservableObject {
    
    // MARK: - Bindings de UI (Datos editables)
    @Published var clienteId: String = ""
    @Published var clienteNombre: String = ""
    @Published var descripcion: String = ""
    @Published var presupuesto: Double = 0.0
    @Published var tipo: TipoPedido = .otros // Asumo que TipoPedido es tu enum (o TipoVenta)
    @Published var fecha: Date = Date()
    @Published var estadoEntrega: Bool = false
    
    // Datos de solo lectura (para mostrar saldos al editar)
    @Published var montoAbonadoOriginal: Double = 0.0
    
    // Estados de UI
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shouldDismiss: Bool = false
    
    // MARK: - Privados
    private let repository = FirestoreTallerRepository.shared
    private let editingPedidoID: String?
    
    // MARK: - Init
    init(pedido: Pedido? = nil) {
        if let p = pedido {
            // MODO EDICIÓN
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
            // MODO CREACIÓN
            self.editingPedidoID = nil
            self.fecha = Date()
            self.tipo = .otros
        }
    }
    
    // MARK: - Lógica Computada
    var isValid: Bool {
        !clienteId.isEmpty && !descripcion.trimmingCharacters(in: .whitespaces).isEmpty && presupuesto >= 0
    }
    
    var isEditing: Bool {
        editingPedidoID != nil
    }
    
    // MARK: - Acciones
    
    func guardar() {
        guard isValid else { return }
        
        self.isLoading = true
        
        Task {
            do {
                // CAMBIO 1: Inicializamos con id: nil.
                // Al no tocar la propiedad @DocumentID, el warning DESAPARECE.
                let pedido = Pedido(
                    id: nil, // <--- LA CLAVE: Lo dejamos limpio
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
                
                // CAMBIO 2: Pasamos el ID por separado para que el Repo sepa qué hacer
                try await repository.savePedido(pedido: pedido, existingID: self.editingPedidoID)
                
                self.shouldDismiss = true
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
