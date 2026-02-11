import SwiftUI
import Combine

struct MainView: View {
    
    // StateObjects (Dueños de los datos)
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var cajaViewModel: CajaViewModel
    @StateObject private var cronogramaViewModel: CronogramaViewModel
    @StateObject private var pedidosViewModel: PedidosViewModel
    @StateObject private var navManager = NavigationManager()

    // Repositorios compartidos (para inyectar en vistas de Gestión)
    private let ventasRepo: VentasRepository
    private let tallerRepo: TallerRepository
    private let finanzasRepo: FinanzasRepository

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
        _dashboardViewModel = StateObject(wrappedValue: dashboardVM)

        // 3. INYECCIÓN EN CAJA (Repos + Conexión de Fechas)
        let cajaVM = CajaViewModel(
            finanzasRepo: finanzasRepo,
            ventasRepo: ventasRepo,
            fechaInicioPublisher: dashboardVM.$fechaInicio.eraseToAnyPublisher(),
            fechaFinPublisher: dashboardVM.$fechaFin.eraseToAnyPublisher()
        )
        _cajaViewModel = StateObject(wrappedValue: cajaVM)

        // 4. INYECCIÓN EN CRONOGRAMA
        let cronogramaVM = CronogramaViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo,
            ventasRepo: ventasRepo
        )
        _cronogramaViewModel = StateObject(wrappedValue: cronogramaVM)

        // 5. INYECCIÓN EN PEDIDOS
        let pedidosVM = PedidosViewModel(
            ventasRepo: ventasRepo,
            finanzasRepo: finanzasRepo
        )
        _pedidosViewModel = StateObject(wrappedValue: pedidosVM)
    }
    
    var body: some View {
        // Enlazamos la selección del Tab con el Manager
        TabView(selection: $navManager.selectedTab) {
            
            // Pestaña 1: Inicio
            NavigationStack {
                DashboardView(viewModel: dashboardViewModel, finanzasRepo: finanzasRepo)
            }
            .tabItem { Label("Inicio", systemImage: "house") }
            .tag(AppTab.inicio)

            // Pestaña 2: Cronograma
            // NOTA: Asegúrate de que CronogramaView espere recibir el viewModel en su init
            CronogramaView(viewModel: cronogramaViewModel)
                .tabItem { Label("Cronograma", systemImage: "calendar") }
                .tag(AppTab.cronograma)

            // Pestaña 3: Pedidos
            NavigationStack {
                PedidosView(viewModel: pedidosViewModel)
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
                GestionView(ventasRepo: ventasRepo, tallerRepo: tallerRepo, finanzasRepo: finanzasRepo)
            }
            .tabItem { Label("Gestión", systemImage: "gearshape") }
            .tag(AppTab.gestion)
        }
        // Inyectamos el navManager al árbol de vistas
        .environmentObject(navManager)
    }
}
