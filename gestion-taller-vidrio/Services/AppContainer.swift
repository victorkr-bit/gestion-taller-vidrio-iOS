import SwiftUI
import Combine

@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Repositorios (compartidos)
    let finanzasRepo: FinanzasRepository
    let tallerRepo: TallerRepository
    let ventasRepo: VentasRepository
    let contactosRepo: ContactosRepository

    // MARK: - Coordinadores
    let filterCoordinator: FilterCoordinator

    // MARK: - ViewModels
    let metricasVM: MetricasViewModel
    let chartsVM: ChartsViewModel
    let proximaActividadVM: ProximaActividadViewModel
    let pagosVM: PagosViewModel
    let agendaVM: AgendaViewModel
    let inscripcionesVM: InscripcionesViewModel
    let catalogoOnlineVM: CatalogoOnlineViewModel
    let pedidosVM: PedidosViewModel
    let deudoresVM: DeudoresViewModel
    let contactoDetailVM: ContactoDetailViewModel

    init() {
        // 1. CREACIÓN DE LA INFRAESTRUCTURA (REPOSITORIOS COMPARTIDOS)
        let finanzasRepo = FinanzasRepository()
        let tallerRepo = TallerRepository()
        let ventasRepo = VentasRepository()
        let contactosRepo = ContactosRepository()

        self.finanzasRepo = finanzasRepo
        self.tallerRepo = tallerRepo
        self.ventasRepo = ventasRepo
        self.contactosRepo = contactosRepo

        // 2. COORDINADOR DE FILTRO COMPARTIDO (Dashboard / Actividad / Facturación)
        let filterCoordinator = FilterCoordinator()
        self.filterCoordinator = filterCoordinator

        // 3. VMs DE DASHBOARD (split de DashboardViewModel)
        self.metricasVM = MetricasViewModel(
            finanzasRepo: finanzasRepo,
            filter: filterCoordinator
        )
        self.chartsVM = ChartsViewModel(
            finanzasRepo: finanzasRepo,
            tallerRepo: tallerRepo,
            filter: filterCoordinator
        )
        self.proximaActividadVM = ProximaActividadViewModel(tallerRepo: tallerRepo)

        // 4. INYECCIÓN EN PAGOS
        self.pagosVM = PagosViewModel(
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 5. INYECCIÓN EN CRONOGRAMA (3 VMs)
        self.agendaVM = AgendaViewModel(tallerRepo: tallerRepo)
        self.catalogoOnlineVM = CatalogoOnlineViewModel(tallerRepo: tallerRepo)
        self.inscripcionesVM = InscripcionesViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 6. INYECCIÓN EN PEDIDOS
        self.pedidosVM = PedidosViewModel(
            ventasRepo: ventasRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 7. INYECCIÓN EN DEUDORES
        self.deudoresVM = DeudoresViewModel(repository: finanzasRepo)

        // 8. DETALLE DE CONTACTO
        self.contactoDetailVM = ContactoDetailViewModel(tallerRepo: tallerRepo)
    }
}
