import SwiftUI

/// Panel para la pestaña "Gestión" que navega a los módulos de
/// "Datos Maestros" (Contactos y Cursos), como se define
/// en la arquitectura.
struct GestionView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    
    var body: some View {
        List {
            Section("Datos Maestros") {
                // Tarea 2.1: Enlace a la vista de Contactos
                NavigationLink(destination: ContactosView()) {
                    Label("Contactos", systemImage: "person.2.fill")
                }
                 
                // Tarea 2.2: Enlace a la vista de Cursos
                NavigationLink(destination: CursosView()) {
                    Label("Catálogo de Cursos", systemImage: "books.vertical.fill")
                }
            }
            
            // --- INICIO DE LA MODIFICACIÓN (Fase 5B) ---
            Section("Finanzas") {
                NavigationLink(destination: DeudoresView()) {
                    Label("Panel de Deudores", systemImage: "person.crop.circle.badge.xmark")
                }
            }
            // --- FIN DE LA MODIFICACIÓN ---
            
            // --- AÑADIDO (Paso 2): Sección de Logout ---
            Section("Sistema") {
                Button(role: .destructive) {
                    // Llamamos a la función para cerrar sesión
                    authViewModel.signOut()
                } label: {
                    // Usamos .destructive (rojo) por defecto
                    Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            // --- FIN DE LA MODIFICACIÓN ---
            
        }
        .navigationTitle("Gestión")
    }
}
        

#Preview {
    NavigationStack {
        GestionView()
    }
}
