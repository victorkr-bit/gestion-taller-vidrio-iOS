import SwiftUI

struct MainView: View {

    @StateObject private var container = AppContainer()
    @StateObject private var navManager = NavigationManager()

    var body: some View {
        TabView(selection: $navManager.selectedTab) {

            // Pestaña 1: Inicio
            NavigationStack {
                DashboardView(viewModel: container.dashboardVM, deudoresVM: container.deudoresVM)
            }
            .tabItem { Label("Inicio", systemImage: "house") }
            .tag(AppTab.inicio)

            // Pestaña 2: Cronograma
            CronogramaView(agendaVM: container.agendaVM, inscripcionesVM: container.inscripcionesVM, catalogoOnlineVM: container.catalogoOnlineVM)
                .tabItem { Label("Cronograma", systemImage: "calendar") }
                .tag(AppTab.cronograma)

            // Pestaña 3: Pedidos
            NavigationStack {
                PedidosView(viewModel: container.pedidosVM)
            }
            .tabItem { Label("Pedidos", systemImage: "tray.and.arrow.down.fill") }
            .tag(AppTab.pedidos)

            // Pestaña 4: Caja
            NavigationStack {
                CajaView(viewModel: container.cajaVM)
            }
            .tabItem { Label("Caja", systemImage: "dollarsign.circle") }
            .tag(AppTab.caja)

            // Pestaña 5: Gestión
            NavigationStack {
                GestionView(ventasRepo: container.ventasRepo, tallerRepo: container.tallerRepo, deudoresVM: container.deudoresVM)
            }
            .tabItem { Label("Gestión", systemImage: "gearshape") }
            .tag(AppTab.gestion)
        }
        .environmentObject(navManager)
    }
}
