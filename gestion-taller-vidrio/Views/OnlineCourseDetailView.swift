import SwiftUI

struct OnlineCourseDetailView: View {
    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    let curso: Curso

    // Control de expansión para el acordeón de pagos
    @State private var expandedInscripcionID: String?
    @State private var inscripcionParaPagar: Inscripcion?
    @State private var inscripcionToEdit: Inscripcion?
    @State private var inscripcionAMover: Inscripcion?
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
                if inscripcionesVM.isLoading {
                    ProgressView()
                } else if inscripcionesVM.inscripciones.isEmpty {
                    Text("No hay ventas registradas aún.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inscripcionesVM.inscripciones) { inscripcion in
                        InscripcionRowView(
                            inscripcion: inscripcion,
                            inscripcionesVM: inscripcionesVM,
                            expandedInscripcionID: $expandedInscripcionID,
                            inscripcionParaPagar: $inscripcionParaPagar,
                            inscripcionToEdit: $inscripcionToEdit,
                            inscripcionAMover: $inscripcionAMover
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
                inscripcionesVM.fetchInscripcionesOnline(cursoID: id)
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
                    inscripcionesVM: inscripcionesVM,
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
                        try await inscripcionesVM.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        .sheet(item: $inscripcionAMover) { inscripcion in
            NavigationStack {
                // Los cursos online no tienen cronogramaId, la lista de destinos queda vacía
                MoverInscripcionView(
                    inscripcionesVM: inscripcionesVM,
                    inscripcion: inscripcion,
                    cronogramasDisponibles: []
                )
            }
        }
        .errorAlert($inscripcionesVM.errorMessage)
    }
}
