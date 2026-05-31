import Foundation
import Combine
import SwiftUI

enum OrdenDeudores: Hashable {
    case montoDescendente
    case fechaDescendente
    case fechaAscendente
}

@MainActor
class DeudoresViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deudores: [DeudorItem] = []
    @Published var searchText: String = ""
    @Published private var searchQuery: String = ""
    @Published var orden: OrdenDeudores = .montoDescendente

    private let taskTracker = TaskTracker()
    private var cancellables = Set<AnyCancellable>()

    private let repository: FinanzasRepository
    private let tallerRepository: TallerRepository

    init(finanzasRepository: FinanzasRepository? = nil, tallerRepository: TallerRepository? = nil) {
        self.repository = finanzasRepository ?? FinanzasRepository()
        self.tallerRepository = tallerRepository ?? TallerRepository()
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in self?.searchQuery = text }
            .store(in: &cancellables)
        fetchDeudores()
    }

    var totalDeudaPedidos: Double {
        deudores.filter { $0.tipo == .pedido }.reduce(0) { $0 + $1.montoAdeudado }
    }

    var totalDeudaInscripciones: Double {
        deudores.filter { $0.tipo == .inscripcion }.reduce(0) { $0 + $1.montoAdeudado }
    }

    var deudoresFiltrados: [DeudorItem] {
        let filtrados: [DeudorItem]
        if searchQuery.isEmpty {
            filtrados = deudores
        } else {
            let query = searchQuery.lowercased()
            filtrados = deudores.filter { deudor in
                deudor.nombreCliente.lowercased().contains(query) ||
                deudor.descripcion.lowercased().contains(query) ||
                deudor.tipo.rawValue.lowercased().contains(query) ||
                (deudor.estaVencida && "vencida".contains(query))
            }
        }
        switch orden {
        case .montoDescendente: return filtrados.sorted { $0.montoAdeudado > $1.montoAdeudado }
        case .fechaDescendente:  return filtrados.sorted { $0.fecha > $1.fecha }
        case .fechaAscendente:   return filtrados.sorted { $0.fecha < $1.fecha }
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
                self.errorMessage = "Error al cargar deudores: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }

    func fetchCronogramaItem(id: String) async -> CronogramaItem? {
        return try? await tallerRepository.fetchCronogramaItem(id: id)
    }
}
