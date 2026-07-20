import SwiftUI

// Tarea 1.6.1: Componente de vista reutilizable que aplica el estilo "card"
struct CardView<Content: View>: View {

    let content: Content
    /// Tinte opcional para distinguir visualmente la tarjeta (ej. preinscriptos).
    /// Se mezcla con opacidad baja sobre el fondo base, por lo que se adapta solo a modo claro/oscuro.
    let tint: Color?

    // Inicializador que usa un @ViewBuilder
    // Permite pasar múltiples vistas (Text, Spacer, Vstack, etc.)
    // Ejemplo de uso: CardView { Text("Hola") }
    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding() // Padding interno para el contenido
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta)
                            .fill((tint ?? .clear).opacity(0.12))
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
            .sombraTarjeta()
    }
}

