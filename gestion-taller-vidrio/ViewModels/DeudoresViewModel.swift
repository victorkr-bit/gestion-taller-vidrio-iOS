import Foundation
import Combine
import SwiftUI

@MainActor
class DeudoresViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deudores: [DeudorItem] = []
    
    // CAMBIO 1: Repo de Finanzas
    private let repository: FinanzasRepository
    
    // CAMBIO 2: Init
    init(repository: FinanzasRepository? = nil) {
        self.repository = repository ?? FinanzasRepository()
        fetchDeudores()
    }
    
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
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        do {
            try await repository.registrarPago(pago: pago, origen: origen)
            fetchDeudores()
        } catch {
            throw error
        }
    }
    
    func condonarDeuda(origen: Origen) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await repository.condonarDeuda(origen: origen)
                fetchDeudores()
            } catch {
                self.errorMessage = "Error al condonar la deuda: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
