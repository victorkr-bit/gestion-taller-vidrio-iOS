import SwiftUI

// Tarea 1.6.1: Componente de vista reutilizable que aplica el estilo "card"
struct CardView<Content: View>: View {
    
    let content: Content
    
    // Inicializador que usa un @ViewBuilder
    // Permite pasar múltiples vistas (Text, Spacer, Vstack, etc.)
    // Ejemplo de uso: CardView { Text("Hola") }
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding() // Padding interno para el contenido
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // Tarea 1.6.3: Usamos colores semánticos
                // .background es obsoleto, usamos la nueva forma
                // que respeta el modo oscuro/claro automáticamente.
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Sombra sutil
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

