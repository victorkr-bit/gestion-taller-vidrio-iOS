import SwiftUI
import Combine

@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Repositorios (compartidos)
    let finanzasRepo: FinanzasRepository
    let tallerRepo: TallerRepository
    let ventasRepo: VentasRepository

    // MARK: - ViewModels
    let dashboardVM: DashboardViewModel
    let cajaVM: CajaViewModel
    let agendaVM: AgendaViewModel
    let inscripcionesVM: InscripcionesViewModel
    let catalogoOnlineVM: CatalogoOnlineViewModel
    let pedidosVM: PedidosViewModel
    let deudoresVM: DeudoresViewModel

    init() {
        // 1. CREACIÓN DE LA INFRAESTRUCTURA (REPOSITORIOS COMPARTIDOS)
        let finanzasRepo = FinanzasRepository()
        let tallerRepo = TallerRepository()
        let ventasRepo = VentasRepository()

        self.finanzasRepo = finanzasRepo
        self.tallerRepo = tallerRepo
        self.ventasRepo = ventasRepo

        // 2. INYECCIÓN EN DASHBOARD
        let dashboardVM = DashboardViewModel(
            finanzasRepo: finanzasRepo,
            tallerRepo: tallerRepo
        )
        self.dashboardVM = dashboardVM

        // 3. INYECCIÓN EN CAJA
        self.cajaVM = CajaViewModel(
            finanzasRepo: finanzasRepo,
            ventasRepo: ventasRepo
        )

        // 4. INYECCIÓN EN CRONOGRAMA (3 VMs)
        self.agendaVM = AgendaViewModel(tallerRepo: tallerRepo)
        self.catalogoOnlineVM = CatalogoOnlineViewModel(tallerRepo: tallerRepo)
        self.inscripcionesVM = InscripcionesViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo,
            ventasRepo: ventasRepo
        )

        // 5. INYECCIÓN EN PEDIDOS
        self.pedidosVM = PedidosViewModel(
            ventasRepo: ventasRepo,
            finanzasRepo: finanzasRepo
        )

        // 6. INYECCIÓN EN DEUDORES
        self.deudoresVM = DeudoresViewModel(repository: finanzasRepo)
    }
}
