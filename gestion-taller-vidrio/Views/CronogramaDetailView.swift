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
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                InscripcionFormView(
                    viewModel: viewModel,
                    inscripcionToEdit: nil,
                    cronogramaItem: cronogramaItem,
                    curso: nil
                )
            }
        }
        .sheet(item: $inscripcionToEdit) { inscripcion in
            NavigationStack {
                InscripcionFormView(
                    viewModel: viewModel,
                    inscripcionToEdit: inscripcion,
                    cronogramaItem: cronogramaItem,
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
        .errorAlert($viewModel.errorMessage)
    }
}

// MARK: - Subvista para la Fila (Row)
struct InscripcionRowView: View {
    let inscripcion: Inscripcion
    @ObservedObject var viewModel: CronogramaViewModel
    
    @Binding var expandedInscripcionID: String?
    @Binding var inscripcionParaPagar: Inscripcion?
    @Binding var inscripcionToEdit: Inscripcion?

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            CardView {
                HStack {
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
                            inscripcion.turnos ?? 0 > 1 ? TagConfig(text: "\(inscripcion.turnos!) turnos", color: .mint) : nil,
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
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                if expandedInscripcionID == inscripcion.id {
                    viewModel.stopListeningPagos(para: inscripcion)
                    expandedInscripcionID = nil
                } else {
                    expandedInscripcionID = inscripcion.id
                    viewModel.fetchPagos(para: inscripcion)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                self.inscripcionParaPagar = inscripcion
            } label: {
                Label("Pagar", systemImage: "dollarsign.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            .tint(.red)

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
                showDeleteAlert = true
            } label: {
                Label("Eliminar Inscripción", systemImage: "trash")
            }
        }
        .alert("Eliminar Inscripción", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                viewModel.deleteInscripcion(inscripcion)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminar la inscripción de \(inscripcion.alumno_nombre)? Esta acción no se puede deshacer.")
        }

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


