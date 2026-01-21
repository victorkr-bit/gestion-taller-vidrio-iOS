//
//  DeudoresViewModel.swift
//  gestiontaller
//
//  Created by Victor Krongold on 15/11/2025.
//


import Foundation
import Combine
import SwiftUI // Para @MainActor

@MainActor
class DeudoresViewModel: ObservableObject {
    
    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deudores: [DeudorItem] = []
    
    // MARK: - Dependencias
    private let repository = FirestoreTallerRepository.shared
    
    // MARK: - Inicializador
    init() {
        fetchDeudores()
    }
    
    // MARK: - Intenciones (Lógica de UI)
    
    /// Carga la lista de todos los deudores
    func fetchDeudores() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                self.deudores = try await repository.fetchDeudores()
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al cargar deudores: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Llama al Flujo 1 (Registrar Pago) y refresca la lista
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        
        do {
            try await repository.registrarPago(pago: pago, origen: origen)
            // Si tiene éxito, refrescamos la lista
            fetchDeudores()
        } catch {
            // Pasamos el error para que el sheet de pago lo muestre
            throw error
        }
    }
    
    /// Llama al Flujo 6 (Condonar Deuda) y refresca la lista
    func condonarDeuda(origen: Origen) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await repository.condonarDeuda(origen: origen)
                // Si tiene éxito, refrescamos la lista
                fetchDeudores()
            } catch {
                self.errorMessage = "Error al condonar la deuda: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
