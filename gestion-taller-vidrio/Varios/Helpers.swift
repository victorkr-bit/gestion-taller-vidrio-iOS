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

    var body: some View {
        VStack(spacing: 0) {
            filtrRow(label: "Desde", mes: $desde.mes, año: $desde.año)
            Divider().padding(.horizontal)
            filtrRow(label: "Hasta", mes: $hasta.mes, año: $hasta.año)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func filtrRow(label: String, mes: Binding<Int>, año: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()
                .padding(.leading, 14)

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
        Task {
            _ = await task.result
            self.tasks.removeValue(forKey: id)
        }
    }

    nonisolated func cancelAll() {
        MainActor.assumeIsolated {
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
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
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.wrappedValue ?? "Ocurrió un error desconocido.")
        }
    }
}
