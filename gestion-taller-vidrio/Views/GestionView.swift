import SwiftUI

/// Panel para la pestaña "Gestión" que navega a los módulos de
/// "Datos Maestros" (Contactos y Cursos), como se define
/// en la arquitectura.
struct GestionView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    let ventasRepo: VentasRepository
    let tallerRepo: TallerRepository
    let deudoresVM: DeudoresViewModel
    let contactoDetailVM: ContactoDetailViewModel

    var body: some View {
        List {
            Section("Datos Maestros") {
                NavigationLink(destination: ContactosView(ventasRepo: ventasRepo, detailVM: contactoDetailVM)) {
                    Label("Contactos", systemImage: "person.2.fill")
                }

                NavigationLink(destination: CursosView(tallerRepo: tallerRepo)) {
                    Label("Catálogo de Cursos", systemImage: "books.vertical.fill")
                }
            }

            Section("Finanzas") {
                NavigationLink(destination: DeudoresView(viewModel: deudoresVM)) {
                    Label("Deudores", systemImage: "person.crop.circle.badge.xmark")
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
        GestionView(ventasRepo: VentasRepository(), tallerRepo: TallerRepository(), deudoresVM: DeudoresViewModel(), contactoDetailVM: ContactoDetailViewModel(tallerRepo: TallerRepository()))
    }
}
