import SwiftUI

/// Panel para la pestaña "Gestión" que navega a los módulos de
/// "Datos Maestros" (Contactos y Cursos), como se define
/// en la arquitectura.
struct GestionView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    let contactosRepo: ContactosRepository
    let tallerRepo: TallerRepository
    let deudoresVM: DeudoresViewModel
    let contactoDetailVM: ContactoDetailViewModel
    let leadsVM: LeadsViewModel
    let inscripcionesVM: InscripcionesViewModel
    let metricasVM: MetricasViewModel
    let chartsVM: ChartsViewModel
    let filter: FilterCoordinator

    var body: some View {
        List {
            Section("Datos Maestros") {
                NavigationLink(destination: ContactosView(contactosRepo: contactosRepo, detailVM: contactoDetailVM)) {
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
                NavigationLink(destination: ActividadComercialView(chartsVM: chartsVM, filter: filter)) {
                    Label("Actividad", systemImage: "chart.xyaxis.line")
                }
            }

            Section("Finanzas") {
                NavigationLink(destination: DeudoresView(viewModel: deudoresVM)) {
                    Label("Deudores", systemImage: "person.crop.circle.badge.xmark")
                }
                NavigationLink(destination: FacturacionView(metricasVM: metricasVM, chartsVM: chartsVM, filter: filter)) {
                    Label("Facturación", systemImage: "chart.bar.xaxis")
                }
            }

            Section("Sistema") {
                Button(role: .destructive) {
                    authViewModel.signOut()
                } label: {
                    Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Gestión")
    }
}


#Preview {
    let tallerRepo = TallerRepository()
    let finanzasRepo = FinanzasRepository()
    let filter = FilterCoordinator()
    NavigationStack {
        GestionView(
            contactosRepo: ContactosRepository(),
            tallerRepo: tallerRepo,
            deudoresVM: DeudoresViewModel(),
            contactoDetailVM: ContactoDetailViewModel(tallerRepo: tallerRepo),
            leadsVM: LeadsViewModel(tallerRepo: tallerRepo),
            inscripcionesVM: InscripcionesViewModel(tallerRepo: tallerRepo, finanzasRepo: finanzasRepo, contactosRepo: ContactosRepository()),
            metricasVM: MetricasViewModel(finanzasRepo: finanzasRepo, filter: filter),
            chartsVM: ChartsViewModel(finanzasRepo: finanzasRepo, tallerRepo: tallerRepo, filter: filter),
            filter: filter
        )
    }
}
