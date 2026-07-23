import SwiftUI

struct InscripcionRowView: View {
    let inscripcion: Inscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    @Binding var expandedInscripcionID: String?
    @Binding var inscripcionParaPagar: Inscripcion?
    @Binding var inscripcionToEdit: Inscripcion?
    @Binding var inscripcionAMover: Inscripcion?

    @State private var showDeleteAlert = false

    /// Construye las etiquetas de la inscripción: estado de pago, cantidad de turnos y ocupación del taller.
    private func tags(ocupacion: Int) -> [TagConfig] {
        let pagado = inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0
        let turnos = inscripcion.turnos ?? 0

        return [
            TagConfig(text: pagado ? "Pagado" : "Debe \(Formatters.money(inscripcion.monto_adeudado))",
                      color: pagado ? .green : .orange),
            turnos >= 1 ? TagConfig(text: "\(turnos) \(turnos == 1 ? "turno" : "turnos")", color: .mint) : nil,
            (inscripcion.cursoTipo == .taller && ocupacion > 0)
                ? TagConfig(text: "Ocup: \(ocupacion)", color: ocupacion >= 4 ? .red : .blue) : nil
        ].compactMap { $0 }
    }

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
                let ocupacion = inscripcionesVM.ocupacionPorInscripcion[inscripcion.id ?? ""] ?? 0

                HStack(alignment: .center, spacing: DesignSystem.Espaciado.m) {
                    VStack(alignment: .leading, spacing: DesignSystem.Espaciado.sm) {

                        // Línea 1: nombre + hora (en la misma línea superior)
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Espaciado.s) {
                            Text(inscripcion.alumno_nombre)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: DesignSystem.Espaciado.s)

                            if let hora = inscripcion.horario_inicio {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text(hora)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                        // Línea 2: notas (opcional)
                        if let notas = inscripcion.notas, !notas.isEmpty {
                            Text(notas)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        // Línea 3: tags en fila horizontal
                        HStack(spacing: DesignSystem.Espaciado.xs) {
                            ForEach(tags(ocupacion: ocupacion)) { tag in
                                Text(tag.text)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, DesignSystem.Espaciado.s)
                                    .padding(.vertical, DesignSystem.Espaciado.xs)
                                    .background(tag.color.opacity(0.15))
                                    .foregroundStyle(tag.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }

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
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
