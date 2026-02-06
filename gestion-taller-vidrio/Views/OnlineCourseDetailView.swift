import SwiftUI

struct OnlineCourseDetailView: View {
    @ObservedObject var viewModel: CronogramaViewModel
    let curso: Curso
    
    // Control de expansión para el acordeón de pagos
    @State private var expandedInscripcionID: String?
    @State private var inscripcionParaPagar: Inscripcion?
    @State private var inscripcionToEdit: Inscripcion?
    @State private var isSelling = false
    
    var body: some View {
        List {
            // Sección 1: Info del Producto
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(curso.nombre)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("Producto Evergreen (Online)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Total Alumnos: \(curso.inscriptosTotales)")
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Sección 2: Lista de Alumnos (Histórico Global)
            Section(header: Text("Alumnos Inscriptos")) {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.inscripciones.isEmpty {
                    Text("No hay ventas registradas aún.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.inscripciones) { inscripcion in
                        InscripcionRowView(
                            inscripcion: inscripcion,
                            viewModel: viewModel,
                            expandedInscripcionID: $expandedInscripcionID,
                            inscripcionParaPagar: $inscripcionParaPagar,
                            inscripcionToEdit: $inscripcionToEdit
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Detalle Online")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let id = curso.id {
                viewModel.fetchInscripcionesOnline(cursoID: id)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSelling = true
                } label: {
                    Label("Vender", systemImage: "plus")
                }
            }
        }
        
        .sheet(isPresented: $isSelling) {
            NavigationStack {
                InscripcionFormView(
                    viewModel: viewModel,
                    inscripcionToEdit: nil,
                    cronogramaItem: nil,
                    curso: curso
                )
            }
        }
        .sheet(item: $inscripcionParaPagar) { inscripcion in
            NavigationStack {
                RegistrarPagoView(
                    origen: .inscripcion(inscripcion),
                    onSave: { (pago, origen) in
                        try await viewModel.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        .errorAlert($viewModel.errorMessage)
    }
}
