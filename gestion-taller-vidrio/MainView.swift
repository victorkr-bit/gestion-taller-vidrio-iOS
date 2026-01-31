import SwiftUI
import Combine

struct MainView: View {
    
    // StateObjects (Dueños de los datos)
    // NOTA: Ya no los inicializamos aquí con "= ViewModel()", lo haremos en el init
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var cajaViewModel: CajaViewModel
    @StateObject private var cronogramaViewModel: CronogramaViewModel
    
    // El Manager de Navegación sí puede inicializarse aquí porque no tiene dependencias complejas
    @StateObject private var navManager = NavigationManager()

    init() {
        // 1. CREACIÓN DE LA INFRAESTRUCTURA (REPOSITORIOS COMPARTIDOS)
        // Creamos las instancias UNA sola vez para pasarlas a todos los ViewModels.
        // Esto asegura que si el Dashboard actualiza algo en "Finanzas", la Caja lo sepa.
        let finanzasRepo = FinanzasRepository()
        let tallerRepo = TallerRepository()
        let ventasRepo = VentasRepository()
        
        // 2. INYECCIÓN EN DASHBOARD
        let dashboardVM = DashboardViewModel(
            finanzasRepo: finanzasRepo,
            tallerRepo: tallerRepo
        )
        // Asignamos al StateObject subyacente (la variable con guión bajo)
        _dashboardViewModel = StateObject(wrappedValue: dashboardVM)
        
        // 3. INYECCIÓN EN CAJA (Repos + Conexión de Fechas)
        let cajaVM = CajaViewModel(
            finanzasRepo: finanzasRepo,
            ventasRepo: ventasRepo,
            // Aquí pasamos los cables para que el filtro del Dashboard controle la Caja
            fechaInicioPublisher: dashboardVM.$fechaInicio.eraseToAnyPublisher(),
            fechaFinPublisher: dashboardVM.$fechaFin.eraseToAnyPublisher()
        )
        _cajaViewModel = StateObject(wrappedValue: cajaVM)
        
        // 4. INYECCIÓN EN CRONOGRAMA
        let cronogramaVM = CronogramaViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo
        )
        _cronogramaViewModel = StateObject(wrappedValue: cronogramaVM)
    }
    
    var body: some View {
        // Enlazamos la selección del Tab con el Manager
        TabView(selection: $navManager.selectedTab) {
            
            // Pestaña 1: Inicio
            NavigationStack {
                DashboardView(viewModel: dashboardViewModel)
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
                // NOTA: Idealmente PedidosView debería recibir 'ventasRepo' también,
                // pero si usa su propio StateObject interno funcionará (aunque tendrá su propia instancia de repo)
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
        // Inyectamos el navManager al árbol de vistas
        .environmentObject(navManager)
    }
}
