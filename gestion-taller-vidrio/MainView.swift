import SwiftUI
import Combine

struct MainView: View {
    
    // --- INICIO DE LA CORRECCIÓN ---
    
    // 1. Declaramos las propiedades. MainView POSEE ambos VMs.
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var cajaViewModel: CajaViewModel

    // 2. Implementamos el init() para la inyección de dependencias
    init() {
        // 3. Creamos el VM "Fuente" (Dashboard) primero, como variable local
        let dashboardVM = DashboardViewModel()
        
        // 4. Creamos el VM "Dependiente" (Caja) usando los publicadores del primero
        let cajaVM = CajaViewModel(
            fechaInicioPublisher: dashboardVM.$fechaInicio.eraseToAnyPublisher(),
            fechaFinPublisher: dashboardVM.$fechaFin.eraseToAnyPublisher()
        )
        
        // 5. Asignamos las variables locales a las propiedades @StateObject.
        //    Esta es la sintaxis correcta para inicializar @StateObject
        //    dentro de un init y resuelve el error "'self' used...".
        _dashboardViewModel = StateObject(wrappedValue: dashboardVM)
        _cajaViewModel = StateObject(wrappedValue: cajaVM)
    }
    // --- FIN DE LA CORRECCIÓN ---
    
    var body: some View {
        TabView {
            // Pestaña 1: Inicio
            NavigationStack {
                // Pasamos el VM que POSEEMOS
                DashboardView(viewModel: dashboardViewModel)
            }
            .tabItem {
                Label("Inicio", systemImage: "house")
            }

            // Pestaña 2: Cronograma
            NavigationStack {
                CronogramaView()
            }
            .tabItem {
                Label("Cronograma", systemImage: "calendar")
            }

            // Pestaña 3: Pedidos
            NavigationStack {
                PedidosView()
            }
            .tabItem {
                Label("Pedidos", systemImage: "tray.and.arrow.down.fill")
            }

            // Pestaña 4: Caja
            NavigationStack {
                // Pasamos el VM que POSEEMOS
                CajaView(viewModel: cajaViewModel)
            }
            .tabItem {
                Label("Caja", systemImage: "dollarsign.circle")
            }

            // Pestaña 5: Gestión
            NavigationStack {
                GestionView()
            }
            .tabItem {
                Label("Gestión", systemImage: "gearshape")
            }
        }
    }
}
