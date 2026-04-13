import SwiftUI

struct InscripcionRowView: View {
    let inscripcion: Inscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    @Binding var expandedInscripcionID: String?
    @Binding var inscripcionParaPagar: Inscripcion?
    @Binding var inscripcionToEdit: Inscripcion?
    @Binding var inscripcionAMover: Inscripcion?

    @State private var showDeleteAlert = false

    var body: some View {
        Button {
            withAnimation {
                if expandedInscripcionID == inscripcion.id {
                    inscripcionesVM.stopListeningPagos(para: inscripcion)
                    expandedInscripcionID = nil
                } else {
                    expandedInscripcionID = inscripcion.id
                    inscripcionesVM.fetchPagos(para: inscripcion)
                }
            }
        } label: {
            CardView {
                HStack {
                    let ocupacion = inscripcionesVM.ocupacionPorInscripcion[inscripcion.id ?? ""] ?? 0

                    GenericRowView(
                        titulo: inscripcion.alumno_nombre,
                        subtitulo: inscripcion.notas.flatMap { $0.isEmpty ? nil : $0 },
                        infoSuperior: inscripcion.horario_inicio,
                        iconoSuperior: "clock",
                        monto: nil,
                        tags: [
                            TagConfig(text: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? "Pagado" : "Debe \(Formatters.money(inscripcion.monto_adeudado))",
                                      color: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? .green : .orange),
                            inscripcion.turnos ?? 0 > 1 ? TagConfig(text: "\(inscripcion.turnos!) turnos", color: .mint) : nil,
                            (inscripcion.cursoTipo == .taller && ocupacion > 0) ?
                                TagConfig(text: "Ocup: \(ocupacion)", color: ocupacion >= 4 ? .red : .blue) : nil
                        ].compactMap { $0 }
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expandedInscripcionID == inscripcion.id ? 90 : 0))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if inscripcion.monto_adeudado > 0 {
                Button {
                    self.inscripcionParaPagar = inscripcion
                } label: {
                    Label("Pagar", systemImage: "dollarsign.circle.fill")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            .tint(.red)

            Button {
                self.inscripcionToEdit = inscripcion
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)

            Button {
                self.inscripcionAMover = inscripcion
            } label: {
                Label("Mover", systemImage: "arrow.right.circle.fill")
            }
            .tint(.orange)
        }
        .contextMenu {
            if inscripcion.monto_adeudado > 0 {
                Button {
                    self.inscripcionParaPagar = inscripcion
                } label: {
                    Label("Registrar Pago", systemImage: "dollarsign.circle")
                }
            }

            Button {
                self.inscripcionToEdit = inscripcion
            } label: {
                Label("Editar Inscripción", systemImage: "pencil")
            }

            Button {
                self.inscripcionAMover = inscripcion
            } label: {
                Label("Mover inscripción", systemImage: "arrow.right.circle")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Eliminar Inscripción", systemImage: "trash")
            }
        }
        .alert("Eliminar Inscripción", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                inscripcionesVM.deleteInscripcion(inscripcion)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminar la inscripción de \(inscripcion.alumno_nombre)? Esta acción no se puede deshacer.")
        }

        if expandedInscripcionID == inscripcion.id {
            PagosListView(inscripcion: inscripcion, inscripcionesVM: inscripcionesVM)
        }
    }
}
