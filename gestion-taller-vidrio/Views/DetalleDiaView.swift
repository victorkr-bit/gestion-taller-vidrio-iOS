import SwiftUI

struct DetalleDiaView: View {
    let item: CronogramaItem
    var onVerCurso: (() -> Void)? = nil

    private static let fechaFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_AR")
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        fmt.dateFormat = "EEEE d 'de' MMMM yyyy"
        return fmt
    }()

    private var fechaFormateada: String {
        let s = Self.fechaFormatter.string(from: item.fecha)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private var inscriptosTexto: String {
        let n = item.inscriptosReales
        if n == 0 { return "Sin inscriptos" }
        return "\(n) \(n == 1 ? "inscripto" : "inscriptos")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text(item.cursoTipo.descripcion)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(item.cursoTipo.color)
                .padding(.horizontal, DesignSystem.Espaciado.s)
                .padding(.vertical, DesignSystem.Espaciado.xs)
                .background(item.cursoTipo.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.etiqueta))

            HStack {
                Text(item.cursoNombre)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }

            Text(fechaFormateada)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(inscriptosTexto, systemImage: "person.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Espaciado.l)
        .contentShape(Rectangle())
        .onTapGesture { onVerCurso?() }
    }
}
