import SwiftUI
import Combine

// Definimos los Tabs
enum AppTab: Int {
    case inicio = 0
    case cronograma = 1
    case pedidos = 2
    case caja = 3
    case gestion = 4
}

class NavigationManager: ObservableObject {
    @Published var selectedTab: AppTab = .inicio
    @Published var cronogramaPath = NavigationPath()
    
    func navigateToCourseDetail(_ item: CronogramaItem) {
        // 1. Cambiamos la pestaña y reseteamos el path en el ciclo ACTUAL
        selectedTab = .cronograma
        cronogramaPath = NavigationPath() // Asegura que estemos en la raíz
        
        // 2. Empujamos la vista en el SIGUIENTE ciclo del RunLoop
        // Esto separa el cambio de Tab de la animación de Push
        DispatchQueue.main.async { [weak self] in
            self?.cronogramaPath.append(item)
        }
    }
}
