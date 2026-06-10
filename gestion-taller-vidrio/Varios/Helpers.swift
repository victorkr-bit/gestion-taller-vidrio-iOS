import SwiftUI

// MARK: - MesAño (filtro por mes y año)

struct MesAño: Equatable {
    var mes: Int   // 1–12
    var año: Int

    var fechaInicio: Date {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        return c.date(from: DateComponents(year: año, month: mes, day: 1))!
    }

    var fechaFin: Date {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let primerDelSiguiente = c.date(from: DateComponents(year: año, month: mes + 1, day: 1))
            ?? c.date(from: DateComponents(year: año + 1, month: 1, day: 1))!
        return primerDelSiguiente.addingTimeInterval(-1)
    }

    static func current() -> MesAño {
        let c = Calendar.current
        let now = Date()
        return MesAño(mes: c.component(.month, from: now), año: c.component(.year, from: now))
    }

    var shortLabel: String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")
        return "\(cal.shortMonthSymbols[mes - 1].capitalized) \(año)"
    }
}

struct FiltroMesAñoView: View {
    @Binding var desde: MesAño
    @Binding var hasta: MesAño

    private let meses: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")
        return cal.monthSymbols
    }()
    private let años: [Int] = Array(2023...2030)

    private var esMesActual: Bool {
        let actual = MesAño.current()
        return desde == actual && hasta == actual
    }

    var body: some View {
        VStack(spacing: 0) {
            filtrRow(label: "Desde", mes: $desde.mes, año: $desde.año)
            Divider().padding(.horizontal)
            filtrRow(label: "Hasta", mes: $hasta.mes, año: $hasta.año)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !esMesActual {
                    Button("Mes actual") {
                        let actual = MesAño.current()
                        desde = actual
                        hasta = actual
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func filtrRow(label: String, mes: Binding<Int>, año: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()
                .padding(.leading, DesignSystem.Espaciado.m)

            Spacer()

            Picker("Mes", selection: mes) {
                ForEach(1...12, id: \.self) { i in
                    Text(meses[i - 1].capitalized).tag(i)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120)

            Picker("Año", selection: año) {
                ForEach(años, id: \.self) { a in
                    Text(String(a)).tag(a)
                }
            }
            .pickerStyle(.menu)
            .padding(.trailing, 4)
        }
        .frame(height: 44)
    }
}

// MARK: - Task Tracker (auto-limpieza de Tasks completados)

@MainActor
final class TaskTracker {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func track(_ task: Task<Void, Never>) {
        let id = UUID()
        tasks[id] = task
        Task { [weak self] in
            _ = await task.result
            self?.tasks.removeValue(forKey: id)
        }
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    isolated deinit {
        tasks.values.forEach { $0.cancel() }
    }
}

// MARK: - Keyboard Helpers

func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

extension View {
    /// Cierra el teclado al hacer scroll. Aplicar sobre Form o ScrollView.
    func dismissibleKeyboard() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Estado Vacío Reutilizable

struct EstadoVacioView: View {
    let icono: String
    let mensaje: String
    var colorIcono: Color = .secondary
    var boton: (titulo: String, accion: () -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Espaciado.s) {
            Image(systemName: icono)
                .font(.largeTitle)
                .foregroundStyle(colorIcono)
            Text(mensaje)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Espaciado.l)
            if let boton {
                Button(boton.titulo, action: boton.accion)
                    .font(.subheadline)
                    .padding(.top, DesignSystem.Espaciado.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Espaciado.xl)
    }
}

// MARK: - Botón Primario Reutilizable

struct BotonPrimario: View {
    let titulo: String
    let accion: () -> Void
    var estaDeshabilitado: Bool = false
    var estaCargando: Bool = false
    var mensajeValidacion: String? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Espaciado.xs) {
            if estaDeshabilitado, let mensaje = mensajeValidacion {
                Text(mensaje)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: accion) {
                if estaCargando {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(titulo)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(estaDeshabilitado ? Color.secondary.opacity(0.3) : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
            .disabled(estaDeshabilitado || estaCargando)
        }
    }
}

// MARK: - Error Alert Reutilizable
extension View {
    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        self.alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage.wrappedValue != nil },
            set: { if !$0 { errorMessage.wrappedValue = nil } }
        )) {
        } message: {
            Text(errorMessage.wrappedValue ?? "Ocurrió un error desconocido.")
        }
    }
}
