import SwiftUI

struct InscripcionFormView: View {
    
    @ObservedObject var viewModel: CronogramaViewModel
    
    // --- NUEVO: ViewModel dedicado para crear contactos (igual que en VentaDirecta) ---
    @StateObject private var contactosViewModel = ContactosViewModel()
    
    // --- ENTRADAS (MODO HÍBRIDO) ---
    var inscripcionToEdit: Inscripcion?
    var cronogramaItem: CronogramaItem?
    var curso: Curso?
    
    @Environment(\.dismiss) var dismiss
    
    // --- ESTADOS DE DATOS ---
    @State private var alumnoId: String = ""
    @State private var alumno_nombre: String = ""
    
    // --- NUEVO: Estado para el Sheet de Nuevo Contacto ---
    @State private var showNuevoContactoSheet = false
    
    // --- ESTADOS DE PRECIOS ---
    @State private var valorUnitario: Double = 0.0
    @State private var precioTotal: Double = 0.0
    @State private var valorUnitarioInput: String = ""
    
    // --- ESTADOS DE TALLER ---
    @State private var selectedHour: Int = 18
    @State private var selectedMinute: Int = 00
    @State private var turnos: Int = 1
    
    @State private var contactos: [Contacto] = []
    
    // --- COMPUTED PROPERTIES (Lógica Híbrida) ---
    private var origenNombre: String {
        if let i = inscripcionToEdit { return i.cursoNombre }
        if let c = cronogramaItem { return c.cursoNombre }
        if let k = curso { return k.nombre }
        return "Curso"
    }
    
    private var origenTipo: TipoCurso {
        if let i = inscripcionToEdit { return i.cursoTipo }
        if let c = cronogramaItem { return c.cursoTipo }
        if let k = curso { return k.tipo }
        return .presencial
    }
    
    private var origenPrecioBase: Double {
        if let i = inscripcionToEdit { return i.precio_curso }
        if let c = cronogramaItem { return c.precio_curso }
        if let k = curso { return k.precio }
        return 0.0
    }
    
    private var esTaller: Bool { return origenTipo == .taller }
    
    // Validación
    var isFormValid: Bool {
        !alumnoId.isEmpty && precioTotal >= 0
    }
    
    // Formateador
    var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_AR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    func formatCurrency(_ value: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func recalcularTotal() {
        self.precioTotal = self.valorUnitario * Double(self.turnos)
    }
    
    var body: some View {
        Form {
            // -----------------------------------------------------------
            // SECCIÓN 1: DATOS DEL ALUMNO (MODIFICADA)
            // -----------------------------------------------------------
            Section("Datos del Alumno") {
                if inscripcionToEdit == nil {
                    // --- MODO NUEVO ---
                    HStack {
                        // 1. Selector existente
                        NavigationLink {
                            SelectorContactoView(
                                contactos: contactos,
                                selectedID: $alumnoId,
                                selectedNombre: $alumno_nombre
                            )
                        } label: {
                            HStack {
                                Text("Alumno")
                                Spacer()
                                if alumnoId.isEmpty {
                                    Text("Seleccionar")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(alumno_nombre)
                                        .foregroundStyle(.primary)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                        // 2. NUEVO: Botón (+) para crear alumno al vuelo
                        Divider()
                        
                        Button(action: {
                            showNuevoContactoSheet = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless) // Evita que se active el NavigationLink al tocar esto
                        .padding(.leading, 8)
                    }
                } else {
                    // --- MODO EDICIÓN (Solo lectura) ---
                    HStack {
                        Text("Alumno")
                        Spacer()
                        Text(alumno_nombre)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 2: ESTADO FINANCIERO
            // -----------------------------------------------------------
            if let inscripcion = inscripcionToEdit {
                Section("Estado Financiero Actual") {
                    HStack {
                        Text("Total del Curso")
                            .font(.subheadline)
                        Spacer()
                        Text(formatCurrency(precioTotal))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Total Abonado")
                            .font(.subheadline)
                        Spacer()
                        Text(formatCurrency(inscripcion.monto_abonado))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    let deudaProyectada = precioTotal - inscripcion.monto_abonado
                    HStack {
                        Text("Saldo Pendiente")
                            .font(.subheadline)
                        Spacer()
                        Text(formatCurrency(deudaProyectada))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(deudaProyectada > 0 ? .orange : .green)
                    }
                }
                .listRowBackground(Color(uiColor: .systemGroupedBackground))
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 3: CONFIGURACIÓN Y COSTOS
            // -----------------------------------------------------------
            Section(header: Text("Configuración de Venta")) {
                
                HStack {
                    Text("Producto")
                    Spacer()
                    Text(origenNombre)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(esTaller ? "Valor por Turno" : "Valor del Curso")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", text: $valorUnitarioInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: valorUnitarioInput) { _, newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue { valorUnitarioInput = filtered }
                            self.valorUnitario = Double(valorUnitarioInput) ?? 0.0
                            recalcularTotal()
                        }
                }
                
                if esTaller {
                    Stepper("Cantidad de Turnos: \(turnos)", value: $turnos, in: 1...30)
                        .onChange(of: turnos) { recalcularTotal() }
                }
                
                HStack {
                    Text("Total a Pagar")
                        .fontWeight(.semibold)
                    Spacer()
                    if turnos > 1 {
                        Text("(\(turnos) x \(formatCurrency(valorUnitario)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(formatCurrency(precioTotal))
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .bold()
                }
                .listRowBackground(Color.blue.opacity(0.05))
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 4: HORARIO (SOLO TALLER)
            // -----------------------------------------------------------
            if esTaller {
                Section("Horario de Inicio") {
                    HStack {
                        Text("Hora")
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(hour: selectedHour, minute: selectedMinute)) ?? Date()
                            },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                selectedHour = components.hour ?? 18
                                selectedMinute = components.minute ?? 0
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                }
            }
            
            // -----------------------------------------------------------
            // BOTÓN GUARDAR
            // -----------------------------------------------------------
            Section {
                Button(action: guardarInscripcion) {
                    HStack {
                        Spacer()
                        Text("Guardar Inscripción")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle(inscripcionToEdit == nil ? "Nueva Inscripción" : "Editar Inscripción")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        // --- MODAL DE CREACIÓN DE CLIENTE (INTEGRADO) ---
        .sheet(isPresented: $showNuevoContactoSheet) {
            NavigationStack {
                ContactoFormView(
                    viewModel: contactosViewModel,
                    contactoToEdit: nil,
                    onSaveSuccess: { nuevoContacto in
                        // LÓGICA DE ACTUALIZACIÓN AUTOMÁTICA
                        
                        // 1. Agregar a la lista local para que aparezca si entramos al selector después
                        self.contactos.append(nuevoContacto)
                        // Reordenar por prolijidad
                        self.contactos.sort { $0.nombreCompleto < $1.nombreCompleto }
                        
                        // 2. Seleccionar automáticamente en este formulario
                        if let id = nuevoContacto.id {
                            self.alumnoId = id
                            self.alumno_nombre = nuevoContacto.nombreCompleto
                        }
                    }
                )
            }
        }
        .task { await cargarContactos() }
        .onAppear { inicializarDatos() }
        .onChange(of: alumnoId) { _, nuevoID in
            if let contacto = contactos.first(where: { $0.id == nuevoID }) {
                self.alumno_nombre = contacto.nombreCompleto
            }
        }
    }
    
    // MARK: - LÓGICA DE INICIALIZACIÓN
    private func inicializarDatos() {
        if let inscripcion = inscripcionToEdit {
            alumnoId = inscripcion.alumnoId
            alumno_nombre = inscripcion.alumno_nombre
            turnos = inscripcion.turnos ?? 1
            self.precioTotal = inscripcion.precio_curso
            
            let cantidad = Double(max(1, turnos))
            self.valorUnitario = self.precioTotal / cantidad
            
            if let horario = inscripcion.horario_inicio {
                let componentes = horario.split(separator: ":")
                if componentes.count == 2, let h = Int(componentes[0]), let m = Int(componentes[1]) {
                    selectedHour = h
                    selectedMinute = m
                }
            }
        } else {
            self.valorUnitario = origenPrecioBase
            self.turnos = 1
            recalcularTotal()
        }
        self.valorUnitarioInput = String(Int(self.valorUnitario))
    }
    
    private func cargarContactos() async {
        if inscripcionToEdit != nil { return }
        if contactos.isEmpty {
            do {
                self.contactos = try await FirestoreTallerRepository.shared.fetchContactos()
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    // MARK: - LÓGICA DE GUARDADO
    private func guardarInscripcion() {
        let cronogramaIdToSave = cronogramaItem?.id
        let cursoIdToSave = curso?.id ?? cronogramaItem?.cursoId
        
        var inscripcion = inscripcionToEdit ?? Inscripcion(
            alumnoId: "",
            alumno_nombre: "",
            cronogramaId: cronogramaIdToSave,
            cursoId: cursoIdToSave,
            cursoNombre: origenNombre,
            cursoTipo: origenTipo,
            fecha_curso: cronogramaItem?.fecha ?? Date(),
            precio_curso: 0,
            monto_abonado: 0,
            monto_adeudado: 0,
            estado: .inscripto
        )
        
        inscripcion.alumnoId = alumnoId
        inscripcion.alumno_nombre = alumno_nombre
        inscripcion.precio_curso = precioTotal
        
        if let inscripcionExistente = inscripcionToEdit {
            inscripcion.monto_adeudado = precioTotal - inscripcionExistente.monto_abonado
            inscripcion.estado = (inscripcion.monto_adeudado <= 0) ? .pagado : .inscripto
        } else {
            inscripcion.monto_abonado = 0
            inscripcion.monto_adeudado = precioTotal
            inscripcion.estado = .inscripto
        }
        
        if esTaller {
            let horarioString = String(format: "%02d:%02d", selectedHour, selectedMinute)
            inscripcion.horario_inicio = horarioString
            inscripcion.turnos = turnos
        } else {
            inscripcion.horario_inicio = nil
            inscripcion.turnos = nil
        }
        
        viewModel.saveInscripcion(inscripcion: inscripcion)
        dismiss()
    }
}
