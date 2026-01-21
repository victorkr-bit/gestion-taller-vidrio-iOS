import SwiftUI

struct CronogramaDetailView: View {
    
    @ObservedObject var viewModel: CronogramaViewModel
    let cronogramaItem: CronogramaItem
    
    // Estados para navegación y modales
    @State private var inscripcionToEdit: Inscripcion?
    @State private var isCreatingNew = false
    @State private var inscripcionParaPagar: Inscripcion?
    
    // Control de expansión
    @State private var expandedInscripcionID: String?
    
    // Estado de alerta de error
    @State private var showErrorAlert = false
    
    // --- LEAD DEV FEATURE: Ordenamiento Dinámico ---
    // Ordenamos las inscripciones por horario si es un Taller.
    // Si no tienen fecha, las mandamos al final.
    var inscripcionesOrdenadas: [Inscripcion] {
        let lista = viewModel.inscripciones
        
        if cronogramaItem.cursoTipo == .taller {
                 return lista.sorted { (insc1, insc2) -> Bool in
                     // Usamos una comparación numérica real, no lexicográfica
                     let mins1 = TallerCalculator.minutosDesdeMedianoche(from: insc1.horario_inicio) ?? 1439 // 23:59 en mins
                     let mins2 = TallerCalculator.minutosDesdeMedianoche(from: insc2.horario_inicio) ?? 1439
                     return mins1 < mins2
                 }
            } else {
                return lista
            }
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.inscripciones.isEmpty {
                ProgressView("Cargando inscripciones...")
            } else {
                List {
                    // --- Sección 1: Cabecera del Curso ---
                    Section {
                        CardView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cronogramaItem.cursoNombre)
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text(cronogramaItem.fecha, style: .date)
                                    .font(.headline)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    
                    // --- Sección 2: Lista de Inscriptos ---
                    Section(header: Text("Inscriptos (\(viewModel.inscripciones.count))")) {
                        // CAMBIO: Usamos la lista ordenada
                        ForEach(inscripcionesOrdenadas) { inscripcion in
                            InscripcionRowView(
                                inscripcion: inscripcion,
                                viewModel: viewModel,
                                expandedInscripcionID: $expandedInscripcionID,
                                inscripcionParaPagar: $inscripcionParaPagar,
                                inscripcionToEdit: $inscripcionToEdit
                            )
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Detalle del Curso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.isCreatingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // --- SHEETS Y ALERTAS ---
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                InscripcionFormView(
                    viewModel: viewModel,
                    inscripcionToEdit: nil,
                    cronogramaItem: cronogramaItem, // Pasamos el Item de Agenda
                    curso: nil                      // Explicito: No es un curso online
                )
            }
        }
        .sheet(item: $inscripcionToEdit) { inscripcion in
            NavigationStack {
                InscripcionFormView(
                    viewModel: viewModel,
                    inscripcionToEdit: inscripcion,
                    cronogramaItem: cronogramaItem, // Pasamos el contexto de fecha
                    curso: nil
                )
            }
        }
        .sheet(item: $inscripcionParaPagar) { inscripcion in
            NavigationStack {
                RegistrarPagoView(
                    origen: .inscripcion(inscripcion),
                    onSave: { (pago, origen) in
                        try await viewModel.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        .onAppear {
            if let id = cronogramaItem.id {
                viewModel.fetchInscripciones(cronogramaID: id)
            }
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if newValue != nil { showErrorAlert = true }
        }
        .alert("Atención", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Ha ocurrido un error.")
        }
    }
}

// MARK: - Subvista para la Fila (Row) - DEFINITIVA
struct InscripcionRowView: View {
    let inscripcion: Inscripcion
    @ObservedObject var viewModel: CronogramaViewModel
    
    @Binding var expandedInscripcionID: String?
    @Binding var inscripcionParaPagar: Inscripcion?
    @Binding var inscripcionToEdit: Inscripcion?
    
    var body: some View {
        VStack(spacing: 0) {
            CardView {
                HStack {
                    // 1. Recuperamos la ocupación del diccionario de forma segura
                    let ocupacion = viewModel.ocupacionPorInscripcion[inscripcion.id ?? ""] ?? 0
                    
                    GenericRowView(
                        titulo: inscripcion.alumno_nombre,
                        subtitulo: nil, // No mostramos descripción aquí
                        infoSuperior: inscripcion.horario_inicio, // Ej: "18:00"
                        iconoSuperior: "clock",
                        monto: nil, // La fila original no mostraba precio base, solo estado de deuda en tags
                        tags: [
                            TagConfig(text: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? "Pagado" : "Debe \(Formatters.money(inscripcion.monto_adeudado))",
                                      color: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? .green : .orange),
                            // Lógica condicional para mostrar turno si existe
                            inscripcion.turnos ?? 0 > 1 ? TagConfig(text: "\(inscripcion.turnos!) turnos", color: .mint) : nil,
                            // --- NUEVO: Tag de Ocupación ---
                            // Solo mostramos esto si es tipo Taller y la ocupación es relevante (>0)
                            // Puedes ajustar el umbral de color según tu criterio de "taller lleno"
                            (inscripcion.cursoTipo == .taller && ocupacion > 0) ?
                                TagConfig(text: "Ocup: \(ocupacion)", color: ocupacion >= 4 ? .red : .blue) : nil
                        ].compactMap { $0 } // Esto elimina los 'nil' de la lista
                    )
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expandedInscripcionID == inscripcion.id ? 90 : 0))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
        .listRowSeparator(.hidden)
        // IMPORTANTE: Hace que toda el área (incluyendo espacios vacíos) sea 'tappable'
        .contentShape(Rectangle())
        .onTapGesture {
            // Lógica de expansión (Acordeón)
            withAnimation {
                if expandedInscripcionID == inscripcion.id {
                    // COLAPSAR
                    // 1. Dejar de escuchar cambios para ahorrar datos
                    viewModel.stopListeningPagos(para: inscripcion) // <--- AGREGAR ESTO EN EL VIEWMODEL
                    expandedInscripcionID = nil
                } else {
                    // EXPANDIR
                    // 1. Cerrar el anterior si había uno abierto (opcional, pero recomendado)
                    // ... lógica para cerrar el anterior ...
                    
                    expandedInscripcionID = inscripcion.id
                    // 2. Empezar a escuchar
                    viewModel.fetchPagos(para: inscripcion)
                }
            }
        }
        // SWIPE ACTIONS (Ahora funcionan fluido porque no hay botón interfiriendo)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                self.inscripcionParaPagar = inscripcion
            } label: {
                Label("Pagar", systemImage: "dollarsign.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.deleteInscripcion(inscripcion)
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            
            Button {
                self.inscripcionToEdit = inscripcion
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                self.inscripcionParaPagar = inscripcion
            } label: {
                Label("Registrar Pago", systemImage: "dollarsign.circle")
            }
            
            Button {
                self.inscripcionToEdit = inscripcion
            } label: {
                Label("Editar Inscripción", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.deleteInscripcion(inscripcion)
            } label: {
                Label("Eliminar Inscripción", systemImage: "trash")
            }
        }
        
        // Mostrar lista de pagos si está expandido
        // Nota: Esto está fuera del área "tappeable" principal para no colapsar al tocar un pago
        if expandedInscripcionID == inscripcion.id {
            PagosListView(inscripcion: inscripcion, viewModel: viewModel)
        }
    }
}

// MARK: - Subvista para lista de pagos (Helper)
struct PagosListView: View {
    let inscripcion: Inscripcion
    @ObservedObject var viewModel: CronogramaViewModel
    
    var body: some View {
        if let id = inscripcion.id, let pagos = viewModel.pagosPorInscripcion[id] {
            if pagos.isEmpty {
                Text("No hay pagos registrados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(pagos) { pago in
                    PagoRowView(pago: pago)
                        .padding(.leading, 20)
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                }
            }
        } else {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowSeparator(.hidden)
        }
    }
}


