import SwiftUI

/// Fila reutilizable del catálogo de cursos: tocar el encabezado abre la edición,
/// el switch controla la visibilidad en el dropdown de Agenda.
struct CursoRowView: View {
    let curso: Curso
    @ObservedObject var viewModel: CursosViewModel
    let onTap: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onTap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(curso.nombre)
                                .font(.headline)
                                .foregroundStyle(Color.primary)

                            Text(curso.tipo.descripcion)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(curso.tipo.color)
                                .padding(4)
                                .background(curso.tipo.color.opacity(0.15))
                                .cornerRadius(6)
                        }

                        Spacer()

                        Text(Formatters.money(curso.precio))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 6)
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Visible en agenda")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { curso.visible_en_agenda ?? true },
                        set: { _ in viewModel.toggleVisibilidad(curso: curso) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.8, anchor: .trailing)
                }
            }
        }
        .listRowSeparator(.hidden)
    }
}
