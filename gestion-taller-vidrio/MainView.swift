import SwiftUI

struct MainView: View {

    @StateObject private var container = AppContainer()
    @StateObject private var navManager = NavigationManager()

    var body: some View {
        TabView(selection: $navManager.selectedTab) {
            Tab("Inicio", systemImage: "house", value: AppTab.inicio) {
                NavigationStack {
                    DashboardView(
                        metricasVM: container.metricasVM,
                        chartsVM: container.chartsVM,
                        proximaActividadVM: container.proximaActividadVM,
                        filter: container.filterCoordinator,
                        deudoresVM: container.deudoresVM
                    )
                }
            }

            Tab("Pedidos", systemImage: "tray.and.arrow.down.fill", value: AppTab.pedidos) {
                NavigationStack {
                    PedidosView(viewModel: container.pedidosVM)
                }
            }

            Tab("Agenda", systemImage: "calendar", value: AppTab.cronograma) {
                NavigationStack {
                    AgendaView(agendaVM: container.agendaVM, inscripcionesVM: container.inscripcionesVM, catalogoOnlineVM: container.catalogoOnlineVM)
                }
            }

            Tab("Pagos", systemImage: "dollarsign.circle", value: AppTab.pagos) {
                NavigationStack {
                    PagosView(viewModel: container.pagosVM)
                }
            }

            Tab("Gestión", systemImage: "gearshape", value: AppTab.gestion) {
                NavigationStack {
                    GestionView(
                        contactosRepo: container.contactosRepo,
                        tallerRepo: container.tallerRepo,
                        deudoresVM: container.deudoresVM,
                        contactoDetailVM: container.contactoDetailVM,
                        metricasVM: container.metricasVM,
                        chartsVM: container.chartsVM,
                        filter: container.filterCoordinator
                    )
                }
            }
        }
        .environmentObject(navManager)
    }
}
