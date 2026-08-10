import SwiftUI

/// Sheet para confirmar el pago de una preinscripción presencial.
/// Al confirmar llama la Cloud Function `confirmarPreinscripcion` (crea contacto + inscripción + pago).
struct ConfirmarPreinscripcionView: View {

    let preinscripcion: Preinscripcion
    /// Closure de confirmación: monto + medio de pago, o `pagosSplit` (cursos de profesor externo).
    /// Lanza si el backend rechaza.
    let onConfirm: (_ monto: Double, _ medio: MedioDePago, _ pagosSplit: [PagoSplitEntry]?) async throws -> Void

    @Environment(\.dismiss) var dismiss

    private var esProfesorExterno: Bool { preinscripcion.es_profesor_externo == true }

    @State private var monto: Double = 0.0
    @State private var montoInput: String = ""
    @State private var medio_de_pago: MedioDePago = .transferencia

    // Split adelanto/pago (solo cursos de profesor externo)
    @State private var adelantoInput: String = ""
    @State private var adelantoMedio: MedioDePago = .efectivo
    @State private var pagoInput: String = ""
    @State private var pagoMedio: MedioDePago = .efectivo

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var adelanto: Double { Double(adelantoInput) ?? 0 }
    private var pagoSplitMonto: Double { Double(pagoInput) ?? 0 }
    private var montoTotal: Double { esProfesorExterno ? adelanto + pagoSplitMonto : monto }

    private var deudaResultante: Double {
        max(0, preinscripcion.precio_curso - montoTotal)
    }

    private var esPagoTotal: Bool {
        deudaResultante <= 0.01
    }

    private var isFormValid: Bool {
        guard !isSaving else { return false }
        return esProfesorExterno ? (adelanto > 0 || pagoSplitMonto > 0) : monto > 0
    }

    var body: some View {
        Form {
            Section("Alumno") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preinscripcion.nombreCompleto)
                        .font(.headline)
                    if let contacto = preinscripcion.contactoResumen {
                        Text(contacto)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(preinscripcion.cursoNombre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if esProfesorExterno {
                Section {
                    HStack {
                        Text("Adelanto (profesor)")
                        Spacer()
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $adelantoInput.numericOnly())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .disabled(isSaving)
                    }
                    Picker("Medio", selection: $adelantoMedio) {
                        ForEach(MedioDePago.allCases) { medio in
                            Text(medio.rawValue).tag(medio)
                        }
                    }
                    .disabled(isSaving)
                } header: {
                    Text("Adelanto (profesor)")
                } footer: {
                    Text("No entra a la caja de la usuaria.")
                }

                Section {
                    HStack {
                        Text("Pago (caja)")
                        Spacer()
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $pagoInput.numericOnly())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .disabled(isSaving)
                    }
                    Picker("Medio", selection: $pagoMedio) {
                        ForEach(MedioDePago.allCases) { medio in
                            Text(medio.rawValue).tag(medio)
                        }
                    }
                    .disabled(isSaving)
                } header: {
                    Text("Pago (caja)")
                }
            } else {
                Section("Datos del Pago") {
                    HStack {
                        Text("Monto a Pagar")
                            .font(.headline)
                        Spacer()
                        Text("$")
                            .foregroundStyle(.secondary)
                            .font(.headline)
                        TextField("0", text: $montoInput.numericOnly())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Color.accion)
                            .frame(width: 140)
                            .disabled(isSaving)
                            .onChange(of: montoInput) { _, newValue in
                                self.monto = Double(newValue) ?? 0.0
                            }
                    }

                    Picker("Medio de Pago", selection: $medio_de_pago) {
                        ForEach(MedioDePago.allCases) { medio in
                            Text(medio.rawValue).tag(medio)
                        }
                    }
                    .disabled(isSaving)
                }
            }

            Section("Resumen") {
                HStack {
                    Text("Precio del curso")
                    Spacer()
                    Text(Formatters.money(preinscripcion.precio_curso))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Deuda resultante")
                    Spacer()
                    if esPagoTotal {
                        Text("Pago total")
                            .fontWeight(.bold)
                            .foregroundStyle(DesignSystem.Color.exito)
                    } else {
                        Text("Queda debiendo \(Formatters.money(deudaResultante))")
                            .fontWeight(.bold)
                            .foregroundStyle(DesignSystem.Color.alerta)
                    }
                }
            }
        }
        .dismissibleKeyboard()
        .navigationTitle("Confirmar Pago")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .errorAlert($errorMessage)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: confirmar) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Confirmar")
                            .fontWeight(.bold)
                    }
                }
                .disabled(!isFormValid)
            }
        }
        .onAppear {
            // Default: pago total (precio del curso).
            if monto == 0 {
                monto = preinscripcion.precio_curso
                montoInput = String(Int(preinscripcion.precio_curso))
            }
        }
    }

    private func confirmar() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                if esProfesorExterno {
                    var entries: [PagoSplitEntry] = []
                    if adelanto > 0 {
                        entries.append(PagoSplitEntry(monto: adelanto, medioDePago: adelantoMedio, categoriaReparto: .adelanto))
                    }
                    if pagoSplitMonto > 0 {
                        entries.append(PagoSplitEntry(monto: pagoSplitMonto, medioDePago: pagoMedio, categoriaReparto: .pago))
                    }
                    try await onConfirm(montoTotal, adelantoMedio, entries)
                } else {
                    try await onConfirm(monto, medio_de_pago, nil)
                }
                dismiss()
            } catch {
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
                self.isSaving = false
            }
        }
    }
}
