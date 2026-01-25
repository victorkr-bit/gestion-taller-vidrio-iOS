import SwiftUI
import Combine

struct MainView: View {
    
    // StateObjects (Dueños de los datos)
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var cajaViewModel: CajaViewModel
    
    // --- CAMBIO 1: Elevamos CronogramaViewModel ---
    @StateObject private var cronogramaViewModel = CronogramaViewModel()
    
    // --- CAMBIO 2: Inyectamos el Manager de Navegación ---
    @StateObject private var navManager = NavigationManager()

    init() {
        let dashboardVM = DashboardViewModel()
        
        let cajaVM = CajaViewModel(
            fechaInicioPublisher: dashboardVM.$fechaInicio.eraseToAnyPublisher(),
            fechaFinPublisher: dashboardVM.$fechaFin.eraseToAnyPublisher()
        )
        
        _dashboardViewModel = StateObject(wrappedValue: dashboardVM)
        _cajaViewModel = StateObject(wrappedValue: cajaVM)
        // Cronograma y NavManager se inicializan vacíos arriba, es válido.
    }
    
    var body: some View {
        // Enlazamos la selección del Tab con el Manager
        TabView(selection: $navManager.selectedTab) {
            
            // Pestaña 1: Inicio
            NavigationStack {
                DashboardView(viewModel: dashboardViewModel)
            }
            .tabItem { Label("Inicio", systemImage: "house") }
            .tag(AppTab.inicio) // Usamos el enum

            // Pestaña 2: Cronograma
            // NOTA: CronogramaView ahora recibe el path y el VM
            CronogramaView(viewModel: cronogramaViewModel)
                .tabItem { Label("Cronograma", systemImage: "calendar") }
                .tag(AppTab.cronograma)

            // Pestaña 3: Pedidos
            NavigationStack {
                PedidosView()
            }
            .tabItem { Label("Pedidos", systemImage: "tray.and.arrow.down.fill") }
            .tag(AppTab.pedidos)

            // Pestaña 4: Caja
            NavigationStack {
                CajaView(viewModel: cajaViewModel)
            }
            .tabItem { Label("Caja", systemImage: "dollarsign.circle") }
            .tag(AppTab.caja)

            // Pestaña 5: Gestión
            NavigationStack {
                GestionView()
            }
            .tabItem { Label("Gestión", systemImage: "gearshape") }
            .tag(AppTab.gestion)
        }
        // Inyectamos el navManager al árbol de vistas para que Dashboard pueda usarlo
        .environmentObject(navManager)
    }
}
