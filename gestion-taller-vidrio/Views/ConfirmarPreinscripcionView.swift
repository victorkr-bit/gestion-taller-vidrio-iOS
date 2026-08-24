import SwiftUI

/// Sheet para confirmar el pago de una preinscripción presencial.
/// Al confirmar llama la Cloud Function `confirmarPreinscripcion` (crea contacto + inscripción + pago).
struct ConfirmarPreinscripcionView: View {

    let preinscripcion: Preinscripcion
    let contactosRepo: any ContactosRepositorio
    /// Closure de confirmación: monto + medio de pago, `pagosSplit` (cursos de profesor externo),
    /// y la resolución manual de contacto (`contactoId`/`forzarContactoNuevo`, ambos `nil` si el
    /// admin no intervino y el backend debe matchear automático). Lanza si el backend rechaza.
    let onConfirm: (_ monto: Double, _ medio: MedioDePago, _ pagosSplit: [PagoSplitEntry]?, _ contactoId: String?, _ forzarContactoNuevo: Bool?) async throws -> Void

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

    // Preview local de contacto (matching normalizado, espejo del backend)
    @State private var cargandoContactos = true
    @State private var contactos: [Contacto] = []
    @State private var matchAutomatico: Contacto?
    @State private var forzarNuevo = false
    @State private var contactoManualId = ""
    @State private var contactoManualNombre = ""
    @State private var mostrandoSelector = false

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

            Section("Contacto") {
                if cargandoContactos {
                    HStack {
                        ProgressView()
                        Text("Buscando contacto...")
                            .foregroundStyle(.secondary)
                    }
                } else if !contactoManualId.isEmpty {
                    // Elección manual: pisa tanto el match automático como "forzar nuevo".
                    VStack(alignment: .leading, spacing: 6) {
                        Label(contactoManualNombre, systemImage: "person.fill.checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignSystem.Color.exito)
                        HStack(spacing: 16) {
                            Button("Cambiar") { mostrandoSelector = true }
                            Button("Quitar selección") {
                                contactoManualId = ""
                                contactoManualNombre = ""
                            }
                        }
                        .font(.caption)
                    }
                } else if forzarNuevo {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Se creará un contacto nuevo", systemImage: "person.badge.plus")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Button("Deshacer") {
                                forzarNuevo = false
                                matchAutomatico = ContactoMatching.encontrarMatch(
                                    nombre: preinscripcion.nombre,
                                    apellido: preinscripcion.apellido,
                                    email: preinscripcion.email,
                                    telefono: preinscripcion.telefono,
                                    en: contactos
                                )
                            }
                            Button("Elegir otro contacto") { mostrandoSelector = true }
                        }
                        .font(.caption)
                    }
                } else if let match = matchAutomatico {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(match.nombreCompleto, systemImage: "person.fill.checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignSystem.Color.exito)
                        if let resumen = match.email?.isEmpty == false ? match.email : match.telefono {
                            Text(resumen)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            Button("No es la misma persona") {
                                forzarNuevo = true
                                matchAutomatico = nil
                            }
                            Button("Elegir otro contacto") { mostrandoSelector = true }
                        }
                        .font(.caption)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Se creará un contacto nuevo", systemImage: "person.badge.plus")
                            .foregroundStyle(.secondary)
                        Button("Buscar contacto existente") { mostrandoSelector = true }
                            .font(.caption)
                    }
                }
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
        .task {
            let listaContactos = (try? await contactosRepo.fetchContactos()) ?? []
            contactos = listaContactos
            matchAutomatico = ContactoMatching.encontrarMatch(
                nombre: preinscripcion.nombre,
                apellido: preinscripcion.apellido,
                email: preinscripcion.email,
                telefono: preinscripcion.telefono,
                en: listaContactos
            )
            cargandoContactos = false
        }
        .sheet(isPresented: $mostrandoSelector) {
            NavigationStack {
                SelectorContactoView(
                    contactos: contactos,
                    selectedID: $contactoManualId,
                    selectedNombre: $contactoManualNombre
                )
            }
        }
        .onChange(of: contactoManualId) { _, nuevoId in
            // Elegir un contacto a mano pisa "forzar nuevo" (payload no puede mandar ambos).
            if !nuevoId.isEmpty {
                forzarNuevo = false
            }
        }
    }

    private func confirmar() {
        isSaving = true
        errorMessage = nil

        // Resolución manual de contacto: solo se manda si el admin intervino (forzó nuevo o
        // eligió uno distinto a mano). Sin intervención, el backend matchea automático.
        let contactoId = contactoManualId.isEmpty ? nil : contactoManualId
        let forzarContactoNuevo = forzarNuevo ? true : nil

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
                    try await onConfirm(montoTotal, adelantoMedio, entries, contactoId, forzarContactoNuevo)
                } else {
                    try await onConfirm(monto, medio_de_pago, nil, contactoId, forzarContactoNuevo)
                }
                dismiss()
            } catch {
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
                self.isSaving = false
            }
        }
    }
}
