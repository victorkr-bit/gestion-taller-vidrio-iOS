import SwiftUI

// Tarea 4.6: Formulario Modal para Registrar Pago (Flujo 1) - VERSIÓN BLINDADA
struct RegistrarPagoView: View {
    
    // Recibe el origen (Pedido o Inscripcion)
    let origen: Origen
    
    // Recibe el closure de guardado desde el ViewModel padre
    let onSave: (Pago, Origen, [PagoSplitEntry]?) async throws -> Void

    @Environment(\.dismiss) var dismiss

    // --- Estado del Formulario ---
    @State private var monto: Double = 0.0
    @State private var montoInput: String = "" // Input manual

    @State private var medio_de_pago: MedioDePago = .transferencia
    @State private var fecha: Date = Date()
    @State private var notas: String = ""

    // Split adelanto/pago (solo inscripciones de profesor externo)
    @State private var adelantoInput: String = ""
    @State private var adelantoMedio: MedioDePago = .efectivo
    @State private var pagoInput: String = ""
    @State private var pagoMedio: MedioDePago = .efectivo

    // Estados de Control
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        origen: Origen,
        fechaInicial: Date = Date(),
        onSave: @escaping (Pago, Origen, [PagoSplitEntry]?) async throws -> Void
    ) {
        self.origen = origen
        self.onSave = onSave
        _fecha = State(initialValue: fechaInicial)
    }

    private var esProfesorExterno: Bool {
        if case .inscripcion(let inscripcion) = origen { return inscripcion.es_profesor_externo == true }
        return false
    }

    private var adelanto: Double { Double(adelantoInput) ?? 0 }
    private var pagoSplitMonto: Double { Double(pagoInput) ?? 0 }
    private var montoTotal: Double { esProfesorExterno ? adelanto + pagoSplitMonto : monto }

    var isFormValid: Bool {
        guard !isSaving else { return false }
        guard montoTotal <= origen.montoAdeudado else { return false }
        return esProfesorExterno ? (adelanto > 0 || pagoSplitMonto > 0) : monto > 0
    }

    private var excedeDeuda: Bool {
        montoTotal > origen.montoAdeudado && origen.montoAdeudado > 0
    }
    
    var body: some View {
        Form {
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

                Section("Pago (caja)") {
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
                }

                if excedeDeuda {
                    Text("El monto no puede superar la deuda de \(Formatters.money(origen.montoAdeudado))")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Color.peligro)
                }

                Section {
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .disabled(isSaving)
                }
            } else {
                Section("Datos del Pago") {

                    // --- CAMPO DE MONTO ---
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

                    if excedeDeuda {
                        Text("El monto no puede superar la deuda de \(Formatters.money(origen.montoAdeudado))")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Color.peligro)
                    }

                    Picker("Medio de Pago", selection: $medio_de_pago) {
                        ForEach(MedioDePago.allCases) { medio in
                            Text(medio.rawValue).tag(medio)
                        }
                    }
                    .disabled(isSaving)

                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .disabled(isSaving)
                }
            }
            
            Section("Información Adicional") {
                TextField("Notas (Opcional)", text: $notas, axis: .vertical)
                    .lineLimit(3)
                    .disabled(isSaving)
                
                // Informativo
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cliente: \(origen.clienteNombre)")
                    Text("Origen: \(origen.descripcionOrigen)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                infoDeudaRow(monto: origen.montoAdeudado)
            }
            
        }
        .dismissibleKeyboard()
        .navigationTitle("Registrar Pago")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .errorAlert($errorMessage)
        .toolbar {
            // Botón Cancelar
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSaving)
            }
            
            // Botón Confirmar (El importante)
            ToolbarItem(placement: .confirmationAction) {
                Button(action: guardarPago) {
                    if isSaving {
                        // Feedback visual inmediato: Rulito
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Guardar Pago")
                            .fontWeight(.bold)
                    }
                }
                // Bloqueo físico del botón
                .disabled(!isFormValid)
            }
        }
        .onAppear {
            prellenarDatos()
        }
    }
    
    // MARK: - Helpers Visuales
    
    private func infoDeudaRow(monto: Double) -> some View {
        HStack {
            Text("Saldo Pendiente Actual:")
                .font(.subheadline)
            Spacer()
            Text(Formatters.money(monto))
                .fontWeight(.bold)
                .foregroundStyle(monto > 0 ? DesignSystem.Color.alerta : DesignSystem.Color.exito)
        }
    }
    
    // MARK: - Lógica de Pre-llenado
    
    private func prellenarDatos() {
        if monto == 0 {
            var deudaCalculada: Double = 0.0
            
            switch origen {
            case .inscripcion(let inscripcion):
                deudaCalculada = max(0, inscripcion.monto_adeudado)
            case .pedido(let pedido):
                deudaCalculada = max(0, pedido.monto_adeudado)
            }
            
            self.monto = deudaCalculada
            if deudaCalculada > 0 {
                self.montoInput = String(Int(deudaCalculada))
            }
        }
    }
    
    // MARK: - Lógica de Guardado Blindada
    
    private func guardarPago() {
        // 1. BLOQUEO INMEDIATO
        // Al setear esto, la UI se congela y el botón pasa a ProgressView.
        // Es imposible que el usuario toque dos veces.
        isSaving = true
        errorMessage = nil

        let pagosSplit: [PagoSplitEntry]? = {
            guard esProfesorExterno else { return nil }
            var entries: [PagoSplitEntry] = []
            if adelanto > 0 { entries.append(PagoSplitEntry(monto: adelanto, medioDePago: adelantoMedio, categoriaReparto: .adelanto)) }
            if pagoSplitMonto > 0 { entries.append(PagoSplitEntry(monto: pagoSplitMonto, medioDePago: pagoMedio, categoriaReparto: .pago)) }
            return entries
        }()

        let pago = Pago(
            fecha: fecha,
            monto: montoTotal,
            medio_de_pago: esProfesorExterno ? (pagosSplit?.first?.medioDePago ?? medio_de_pago) : medio_de_pago,
            cliente_id: origen.clienteID,
            cliente_nombre: origen.clienteNombre,
            tipo_venta: origen.tipoVenta,
            notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas,
            origen_tipo: origen.tipo,
            descripcion_origen: origen.descripcionOrigen,
            origen_id: origen.id
        )

        Task {
            do {
                // 2. LLAMADA AL BACKEND
                // Esto puede tardar 1, 3 o 10 segundos. La UI sigue bloqueada.
                try await onSave(pago, origen, pagosSplit)
                
                // 3. ÉXITO -> CERRAR
                // Solo cerramos si la línea anterior no lanzó error.
                // No hace falta poner isSaving = false porque la vista desaparece.
                dismiss()
                
            } catch {
                // 4. FALLO -> DESBLOQUEAR
                // Si hubo error (ej. sin internet), mostramos el mensaje
                // y devolvemos el control al usuario para que reintente.
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
                self.isSaving = false
            }
        }
    }
}
