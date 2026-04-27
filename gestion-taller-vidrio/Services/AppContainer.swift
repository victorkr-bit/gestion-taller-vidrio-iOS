import SwiftUI
import Combine

@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Repositorios (compartidos)
    let finanzasRepo: FinanzasRepository
    let tallerRepo: TallerRepository
    let ventasRepo: VentasRepository
    let contactosRepo: ContactosRepository

    // MARK: - ViewModels
    let dashboardVM: DashboardViewModel
    let pagosVM: PagosViewModel
    let agendaVM: AgendaViewModel
    let inscripcionesVM: InscripcionesViewModel
    let catalogoOnlineVM: CatalogoOnlineViewModel
    let pedidosVM: PedidosViewModel
    let deudoresVM: DeudoresViewModel
    let contactoDetailVM: ContactoDetailViewModel
    let leadsVM: LeadsViewModel

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

        // 2. INYECCIÓN EN DASHBOARD
        let dashboardVM = DashboardViewModel(
            finanzasRepo: finanzasRepo,
            tallerRepo: tallerRepo
        )
        self.dashboardVM = dashboardVM

        // 3. INYECCIÓN EN PAGOS
        self.pagosVM = PagosViewModel(
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 4. INYECCIÓN EN CRONOGRAMA (3 VMs)
        self.agendaVM = AgendaViewModel(tallerRepo: tallerRepo)
        self.catalogoOnlineVM = CatalogoOnlineViewModel(tallerRepo: tallerRepo)
        self.inscripcionesVM = InscripcionesViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 5. INYECCIÓN EN PEDIDOS
        self.pedidosVM = PedidosViewModel(
            ventasRepo: ventasRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        // 6. INYECCIÓN EN DEUDORES
        self.deudoresVM = DeudoresViewModel(repository: finanzasRepo)

        // 7. DETALLE DE CONTACTO
        self.contactoDetailVM = ContactoDetailViewModel(tallerRepo: tallerRepo)

        // 8. LEADS
        self.leadsVM = LeadsViewModel(tallerRepo: tallerRepo)
    }
}
