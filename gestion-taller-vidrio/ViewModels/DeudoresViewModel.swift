import Foundation
import Combine
import SwiftUI

@MainActor
class DeudoresViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deudores: [DeudorItem] = []
    @Published var searchText: String = ""
    @Published private var searchQuery: String = ""

    private let taskTracker = TaskTracker()
    private var cancellables = Set<AnyCancellable>()

    // CAMBIO 1: Repo de Finanzas
    private let repository: FinanzasRepository

    // CAMBIO 2: Init
    init(repository: FinanzasRepository? = nil) {
        self.repository = repository ?? FinanzasRepository()
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in self?.searchQuery = text }
            .store(in: &cancellables)
        fetchDeudores()
    }

    var deudoresFiltrados: [DeudorItem] {
        guard !searchQuery.isEmpty else { return deudores }
        let query = searchQuery.lowercased()
        return deudores.filter { deudor in
            deudor.nombreCliente.lowercased().contains(query) ||
            deudor.descripcion.lowercased().contains(query) ||
            deudor.tipo.rawValue.lowercased().contains(query)
        }
    }

    deinit {
        taskTracker.cancelAll()
    }

    func fetchDeudores() {
        isLoading = true
        errorMessage = nil
        taskTracker.track(Task {
            do {
                self.deudores = try await repository.fetchDeudores()
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al cargar deudores: \(error.localizedDescription)"
                self.isLoading = false
            }
        })
    }

    func registrarPago(pago: Pago, origen: Origen) async throws {
        errorMessage = nil
        do {
            try await repository.registrarPago(pago: pago, origen: origen)
            fetchDeudores()
        } catch {
            errorMessage = "Error al registrar pago: \(error.localizedDescription)"
            throw error
        }
    }
    
    func condonarDeuda(origen: Origen) {
        isLoading = true
        errorMessage = nil
        taskTracker.track(Task {
            do {
                try await repository.condonarDeuda(origen: origen)
                fetchDeudores()
            } catch {
                self.errorMessage = "Error al condonar la deuda: \(error.localizedDescription)"
                self.isLoading = false
            }
        })
    }
}
