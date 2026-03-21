import SwiftUI

struct ContactoDetailView: View {

    @State var contacto: Contacto
    @ObservedObject var detailVM: ContactoDetailViewModel
    @ObservedObject var contactosVM: ContactosViewModel

    @State private var isEditing = false

    var body: some View {
        List {
            // MARK: - Info del contacto
            Section {
                if let telefono = contacto.telefono, !telefono.isEmpty {
                    Label(telefono, systemImage: "phone.fill")
                }
                if let email = contacto.email, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                }
                if let direccion = contacto.direccion, !direccion.isEmpty {
                    Label(direccion, systemImage: "mappin.and.ellipse")
                }
                if let redes = contacto.redes_sociales, !redes.isEmpty {
                    Label(redes, systemImage: "at")
                }
                if let cuit = contacto.cuit, !cuit.isEmpty {
                    Label(cuit, systemImage: "doc.text")
                }
                if let notas = contacto.notas, !notas.isEmpty {
                    Label(notas, systemImage: "note.text")
                }
            }

            // MARK: - Inscripciones
            Section("Inscripciones") {
                if detailVM.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if detailVM.inscripciones.isEmpty {
                    Text("Sin inscripciones registradas")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detailVM.inscripciones) { inscripcion in
                        InscripcionHistorialRow(inscripcion: inscripcion)
                    }
                }
            }
        }
        .navigationTitle(contacto.nombreCompleto)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Editar") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                ContactoFormView(
                    viewModel: contactosVM,
                    contactoToEdit: contacto,
                    onSaveSuccess: { contactoActualizado in
                        contacto = contactoActualizado
                    }
                )
            }
        }
        .errorAlert($detailVM.errorMessage)
        .task {
            guard let id = contacto.id else { return }
            await detailVM.cargar(alumnoId: id)
        }
    }
}

// MARK: - Fila de inscripción

private struct InscripcionHistorialRow: View {
    let inscripcion: Inscripcion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(inscripcion.cursoNombre)
                    .font(.headline)
                Spacer()
                tipoBadge
            }
            HStack {
                Text(Formatters.date(inscripcion.fecha_curso))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                estadoLabel
            }
        }
        .padding(.vertical, 2)
    }

    private var tipoBadge: some View {
        Text(inscripcion.cursoTipo.descripcion)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }

    private var estadoLabel: some View {
        Group {
            if inscripcion.estado == .pagado {
                Label("Pagado", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Text("Debe \(Formatters.money(inscripcion.monto_adeudado))")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }
}
