import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MetricasViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var totalIngresosMes: Double = 0.0
    @Published var totalDeuda: Double = 0.0
    @Published var pagosDelMes: [Pago] = []
    @Published var datosGraficoPorTipo: [DatoGraficoTipo] = []

    private var metricasListener: ListenerRegistration?
    private var pagosListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    private let finanzasRepo: FinanzasRepository
    private let filter: FilterCoordinator

    init(finanzasRepo: FinanzasRepository, filter: FilterCoordinator) {
        self.finanzasRepo = finanzasRepo
        self.filter = filter

        startListeners()
        observeFilter()
    }

    deinit {
        metricasListener?.remove()
        pagosListener?.remove()
    }

    private func startListeners() {
        isLoading = true

        metricasListener?.remove()
        metricasListener = finanzasRepo.listenToMetricas { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let metricas):
                self.totalDeuda = metricas.total_deuda_pedidos + metricas.total_deuda_inscripciones
            case .failure(let error):
                self.errorMessage = "Error cargando métricas: \(FirestoreManager.mensajeAmigable(error))"
            }
        }

        restartPagosListener()
    }

    private func observeFilter() {
        filter.$mesInicio
            .combineLatest(filter.$mesFin)
            .dropFirst() // ignorar el valor inicial; ya se cargó en startListeners
            .sink { [weak self] _, _ in
                self?.restartPagosListener()
            }
            .store(in: &cancellables)
    }

    private func restartPagosListener() {
        pagosListener?.remove()

        pagosListener = finanzasRepo.listenToPagos(
            from: filter.mesInicio.fechaInicio,
            to: filter.mesFin.fechaFin
        ) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let pagos):
                self.pagosDelMes = pagos
                self.totalIngresosMes = pagos.reduce(0) { $0 + $1.monto }
                self.recalcularDatosGraficos(pagos)
            case .failure(let error):
                self.errorMessage = "Error cargando pagos: \(FirestoreManager.mensajeAmigable(error))"
            }
        }
    }

    private func recalcularDatosGraficos(_ pagos: [Pago]) {
        let totalGlobal = pagos.reduce(0) { $0 + $1.monto }
        let agrupadosPorTipo = Dictionary(grouping: pagos) { $0.tipo_venta.descripcion }
        self.datosGraficoPorTipo = agrupadosPorTipo.map { (tipo, pagosGrupo) in
            let montoGrupo = pagosGrupo.reduce(0) { $0 + $1.monto }
            let porcentaje = totalGlobal > 0 ? Int((montoGrupo / totalGlobal) * 100) : 0
            return DatoGraficoTipo(tipo: tipo, monto: montoGrupo, porcentaje: porcentaje)
        }.sorted { $0.monto > $1.monto }
    }

    /// Calcula el porcentaje de variación contra los meses inmediatamente anteriores
    /// (ventana de igual duración). Necesita la facturación anual de ChartsViewModel.
    func tendenciaPorcentaje(facturacionAnual: [DatoMensual]) -> Double {
        let cal = Calendar.current
        let duracion = mesRange
        var totalAnterior: Double = 0
        for i in 1...duracion {
            guard let fecha = cal.date(byAdding: .month, value: -i, to: filter.mesInicio.fechaInicio) else { continue }
            let m = cal.component(.month, from: fecha)
            let a = cal.component(.year, from: fecha)
            totalAnterior += facturacionAnual.first { $0.mes == m && $0.año == a }?.total ?? 0
        }
        guard totalAnterior > 0 else { return 0 }
        return ((totalIngresosMes - totalAnterior) / totalAnterior) * 100
    }

    private var mesRange: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month], from: filter.mesInicio.fechaInicio, to: filter.mesFin.fechaFin)
        return max(1, (comps.month ?? 0) + 1)
    }
}
