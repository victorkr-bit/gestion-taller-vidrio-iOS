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
    let leadsVM: LeadsViewModel
    let inscripcionesVM: InscripcionesViewModel

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

            Section("Comercial") {
                NavigationLink(destination: LeadsView(viewModel: leadsVM, inscripcionesVM: inscripcionesVM)) {
                    Label("Leads", systemImage: "person.badge.plus")
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
    let tallerRepo = TallerRepository()
    NavigationStack {
        GestionView(
            ventasRepo: VentasRepository(),
            tallerRepo: tallerRepo,
            deudoresVM: DeudoresViewModel(),
            contactoDetailVM: ContactoDetailViewModel(tallerRepo: tallerRepo),
            leadsVM: LeadsViewModel(tallerRepo: tallerRepo),
            inscripcionesVM: InscripcionesViewModel(tallerRepo: tallerRepo, finanzasRepo: FinanzasRepository(), ventasRepo: VentasRepository())
        )
    }
}
