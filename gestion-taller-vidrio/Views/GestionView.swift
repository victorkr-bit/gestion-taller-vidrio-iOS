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
    let dashboardVM: DashboardViewModel

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
                NavigationLink(destination: ActividadComercialView(viewModel: dashboardVM)) {
                    Label("Actividad", systemImage: "chart.xyaxis.line")
                }
            }

            Section("Finanzas") {
                NavigationLink(destination: DeudoresView(viewModel: deudoresVM)) {
                    Label("Deudores", systemImage: "person.crop.circle.badge.xmark")
                }
                NavigationLink(destination: FacturacionView(viewModel: dashboardVM)) {
                    Label("Facturación", systemImage: "chart.bar.xaxis")
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
    let finanzasRepo = FinanzasRepository()
    NavigationStack {
        GestionView(
            ventasRepo: VentasRepository(),
            tallerRepo: tallerRepo,
            deudoresVM: DeudoresViewModel(),
            contactoDetailVM: ContactoDetailViewModel(tallerRepo: tallerRepo),
            leadsVM: LeadsViewModel(tallerRepo: tallerRepo),
            inscripcionesVM: InscripcionesViewModel(tallerRepo: tallerRepo, finanzasRepo: finanzasRepo, ventasRepo: VentasRepository()),
            dashboardVM: DashboardViewModel(finanzasRepo: finanzasRepo, tallerRepo: tallerRepo)
        )
    }
}
