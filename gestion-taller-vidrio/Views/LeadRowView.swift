import SwiftUI

struct LeadRowView: View {
    let lead: Lead
    @Binding var isSelected: Bool
    let onMarcarNotificado: () -> Void
    let onConvertir: () -> Void
    let onCrearInscripcion: () -> Void
    let onBorrar: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {

                // Header: checkbox · nombre · badge
                HStack(spacing: DesignSystem.Espaciado.sm) {
                    Button { isSelected.toggle() } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isSelected ? DesignSystem.Color.accion : Color.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)

                    Text(lead.nombre)
                        .font(.title3)
                        .fontWeight(.bold)

                    BadgeEstadoLead(estado: lead.estado)

                    Spacer()

                    Button { onBorrar() } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                }

                // Fecha
                if let fecha = lead.fecha_ingreso?.value {
                    Text(Formatters.date(fecha))
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }

                // Grid de campos
                Grid(alignment: .leading, horizontalSpacing: DesignSystem.Espaciado.l, verticalSpacing: DesignSystem.Espaciado.sm) {
                    GridRow {
                        Text("Canal").foregroundStyle(.secondary)
                        Text(lead.canal.capitalized)
                    }
                    GridRow {
                        Text("Contacto").foregroundStyle(.secondary)
                        if let url = chatURL {
                            Link(lead.contacto, destination: url)
                        } else {
                            Text(lead.contacto)
                        }
                    }
                    GridRow {
                        Text("Interés").foregroundStyle(.secondary)
                        Text(lead.curso_interes)
                    }
                    if !lead.notas.isEmpty {
                        GridRow {
                            Text("Notas").foregroundStyle(.secondary)
                            Text(lead.notas)
                        }
                    }
                }
                .font(.subheadline)

                // Botón de acción full-width
                actionButton
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch lead.estado {
        case .pendiente:
            Button { onMarcarNotificado() } label: {
                Text("Marcar notificado").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Color.accion)

        case .notificado:
            Button { onConvertir() } label: {
                Text("Convertir").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Color.exito)

        case .convertido:
            Button { onCrearInscripcion() } label: {
                Text("Crear inscripción").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Color.accion)
        }
    }

    private var chatURL: URL? {
        let canalLower = lead.canal.lowercased()

        if canalLower.contains("email") {
            let email = lead.contacto.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            return URL(string: "mailto:\(encoded)")
        }

        let contactoLimpio = lead.contacto.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: " ", with: "")

        if canalLower.contains("instagram") {
            return URL(string: "https://www.instagram.com/\(contactoLimpio)/")
        } else if canalLower.contains("whatsapp") {
            let digits = lead.contacto.filter(\.isNumber)
            return URL(string: "https://wa.me/\(digits)")
        }
        return nil
    }
}

private struct BadgeEstadoLead: View {
    let estado: EstadoLead

    var body: some View {
        Text(estado.label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, DesignSystem.Espaciado.sm)
            .padding(.vertical, 3)
            .background(estado.color.opacity(0.15))
            .foregroundStyle(estado.color)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.etiqueta))
    }
}
