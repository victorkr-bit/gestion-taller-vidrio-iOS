import SwiftUI

// MARK: - Design System
// Fuente única de verdad para tokens de diseño: radios, sombras y espaciados.
// Usar estos valores en lugar de literales numéricos en las vistas.

enum DesignSystem {

    // MARK: - Radio de esquinas
    enum Radio {
        static let tarjeta:   CGFloat = 12  // CardView, paneles del Dashboard
        static let input:     CGFloat = 10  // TextFields, buscadores, LoginView
        static let etiqueta:  CGFloat = 6   // FilterLabel badges, tipo-curso badges
        static let grafico:   CGFloat = 4   // BarMark en Charts, barras de progreso
        static let indicador: CGFloat = 2   // Puntos de leyenda en gráficos
    }

    // MARK: - Sombras
    enum Sombra {
        static let tarjeta   = SombraConfig(color: .black.opacity(0.1),  radio: 5, x: 0, y: 2)
        static let panel     = SombraConfig(color: .black.opacity(0.1),  radio: 2, x: 0, y: 1)
        static let actividad = SombraConfig(color: .black.opacity(0.08), radio: 6, x: 0, y: 2)
    }

    // MARK: - Espaciado
    enum Espaciado {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let s:   CGFloat = 8
        static let m:   CGFloat = 12
        static let l:   CGFloat = 16
        static let xl:  CGFloat = 20
    }

    // MARK: - Colores semánticos
    enum Color {
        static let accion    = SwiftUI.Color.accentColor   // botones primarios, enlaces
        static let exito     = SwiftUI.Color.green         // pagado, entregado
        static let alerta    = SwiftUI.Color.orange        // debe, pendiente de pago
        static let peligro   = SwiftUI.Color.red           // acciones destructivas
        static let neutro    = SwiftUI.Color.gray          // sin presupuesto, sin estado
        static let pendiente  = SwiftUI.Color.purple        // pendiente de entrega
        static let festividad = SwiftUI.Color.teal          // fiestas judías en el calendario
    }
}

// MARK: - SombraConfig

struct SombraConfig {
    let color: Color
    let radio: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extension

extension View {
    /// Aplica la sombra estándar de tarjeta. Pasar una config distinta para paneles especiales.
    func sombraTarjeta(_ config: SombraConfig = DesignSystem.Sombra.tarjeta) -> some View {
        shadow(color: config.color, radius: config.radio, x: config.x, y: config.y)
    }
}
