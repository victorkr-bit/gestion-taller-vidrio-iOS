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
            let query = searchText.lowercased()
            
            return pagos.filter { pago in
                // 1. Buscamos en Cliente, Descripción o Notas (Lo que ya tenías)
                let coincideTexto = pago.cliente_nombre.lowercased().contains(query) ||
                                    pago.descripcion_origen.lowercased().contains(query) ||
                                    (pago.notas ?? "").lowercased().contains(query)
                
                // 2. NUEVO: Buscamos también en los datos de los TAGS
                // (Medio de pago y Tipo de venta)
                let coincideTags = pago.medio_de_pago.rawValue.lowercased().contains(query) ||
                                   pago.tipo_venta.descripcion.lowercased().contains(query) // Usamos .descripcion para que encuentre "Joyería" con tilde si aplica
                
                return coincideTexto || coincideTags
            }
        }
    }
    
    /// Calcula el total de dinero visible en la lista filtrada
    var totalFiltrado: Double {
        return pagosFiltrados.reduce(0) { $0 + $1.monto }
    }
    
    // MARK: - Filtros de Fecha
    @Published var mesInicio: MesAño = .current() { didSet { restartListener() } }
    @Published var mesFin: MesAño = .current() { didSet { restartListener() } }

    private var listener: ListenerRegistration?
    private let taskTracker = TaskTracker()
    
    // MARK: - Inyección de Dependencias
    private let finanzasRepo: FinanzasRepository
    private let ventasRepo: VentasRepository
    
    // MARK: - Inicializador
    init(
        finanzasRepo: FinanzasRepository? = nil,
        ventasRepo: VentasRepository? = nil
    ) {
        self.finanzasRepo = finanzasRepo ?? FinanzasRepository()
        self.ventasRepo = ventasRepo ?? VentasRepository()
        restartListener()
        fetchContactos()
    }
    
    deinit {
        taskTracker.cancelAll()
        listener?.remove()
    }
    
    // MARK: - Lógica de Caja
    
    func restartListener() {
        isLoading = true
        errorMessage = nil
        listener?.remove()

        listener = finanzasRepo.listenToPagos(from: mesInicio.fechaInicio, to: mesFin.fechaFin) { [weak self] result in
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
        taskTracker.track(Task {
            do {
                try await finanzasRepo.deletePago(pago: pago)
            } catch {
                self.errorMessage = "No se pudo borrar el pago: \(error.localizedDescription)"
            }
        })
    }
    
    // Edición
    func savePagoEditado(pago: Pago, montoAntiguo: Double) {
        isLoading = true
        taskTracker.track(Task {
            do {
                try await finanzasRepo.editPago(pagoActualizado: pago, montoAntiguo: montoAntiguo)
                self.isLoading = false
            } catch {
                self.errorMessage = "Error al editar pago: \(error.localizedDescription)"
                self.isLoading = false
            }
        })
    }
    
    func registrarPago(pago: Pago, origen: Origen) async throws {
        try await finanzasRepo.registrarPago(pago: pago, origen: origen)
    }
    
    // MARK: - Venta Directa
    
    func fetchContactos() {
        taskTracker.track(Task {
            do {
                self.contactos = try await ventasRepo.fetchContactos()
            } catch {
                self.errorMessage = "Error cargando contactos: \(error.localizedDescription)"
            }
        })
    }

    func saveVentaDirecta(pago: Pago) {
        taskTracker.track(Task {
            do {
                try await saveVentaDirectaAsync(pago: pago)
            } catch {
                self.errorMessage = "Error al guardar venta directa: \(error.localizedDescription)"
            }
        })
    }

    func saveVentaDirectaAsync(pago: Pago) async throws {
        try await finanzasRepo.saveVentaDirecta(pago: pago)
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
