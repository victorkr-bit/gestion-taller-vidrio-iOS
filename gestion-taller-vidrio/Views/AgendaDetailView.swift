import SwiftUI

struct AgendaDetailView: View {

    @ObservedObject var agendaVM: AgendaViewModel
    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    let cronogramaItem: CronogramaItem

    // Estados para navegación y modales
    @State private var inscripcionToEdit: Inscripcion?
    @State private var isCreatingNew = false
    @State private var inscripcionParaPagar: Inscripcion?
    @State private var isEditingCronograma = false
    @State private var inscripcionAMover: Inscripcion?

    // Control de expansión
    @State private var expandedInscripcionID: String?

    // Copia local del item, actualizada en tiempo real por onReceive($cursosProximos)
    @State private var localItem: CronogramaItem?
    private var displayItem: CronogramaItem { localItem ?? cronogramaItem }

    var totalAbonado: Double { inscripcionesVM.inscripciones.reduce(0) { $0 + $1.monto_abonado } }
    var totalAdeudado: Double { inscripcionesVM.inscripciones.reduce(0) { $0 + $1.monto_adeudado } }

    var inscripcionesOrdenadas: [Inscripcion] {
        let lista = inscripcionesVM.inscripciones

        if displayItem.cursoTipo == .taller {
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
            if inscripcionesVM.isLoading && inscripcionesVM.inscripciones.isEmpty {
                ProgressView("Cargando inscripciones...")
            } else {
                List {
                    // --- Sección 1: Cabecera del Curso ---
                    Section {
                        CardView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(displayItem.cursoNombre)
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text(displayItem.fecha, style: .date)
                                    .font(.headline)
                                if let notas = displayItem.notas, !notas.isEmpty {
                                    Text(notas)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Divider()
                                HStack {
                                    VStack(alignment: .center, spacing: 2) {
                                        Text("\(inscripcionesVM.inscripciones.count)")
                                            .font(.headline).fontWeight(.bold)
                                        Text("inscriptos")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .center, spacing: 2) {
                                        Text(Formatters.money(totalAbonado))
                                            .font(.headline).fontWeight(.semibold).foregroundStyle(.green)
                                        Text("cobrado")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .center, spacing: 2) {
                                        Text(Formatters.money(totalAdeudado))
                                            .font(.headline).fontWeight(.semibold)
                                            .foregroundStyle(totalAdeudado > 0 ? .orange : .secondary)
                                        Text("adeudado")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    // --- Sección 2: Lista de Inscriptos ---
                    Section {
                        ForEach(inscripcionesOrdenadas) { inscripcion in
                            InscripcionRowView(
                                inscripcion: inscripcion,
                                inscripcionesVM: inscripcionesVM,
                                expandedInscripcionID: $expandedInscripcionID,
                                inscripcionParaPagar: $inscripcionParaPagar,
                                inscripcionToEdit: $inscripcionToEdit,
                                inscripcionAMover: $inscripcionAMover
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
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button("Editar curso", systemImage: "pencil") {
                        self.isEditingCronograma = true
                    }
                    Button("Nueva inscripción", systemImage: "plus") {
                        self.isCreatingNew = true
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingCronograma) {
            NavigationStack {
                EditarAgendaView(agendaVM: agendaVM, cronogramaItem: displayItem)
            }
        }
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                InscripcionFormView(
                    inscripcionesVM: inscripcionesVM,
                    inscripcionToEdit: nil,
                    cronogramaItem: displayItem,
                    curso: nil
                )
            }
        }
        .sheet(item: $inscripcionToEdit) { inscripcion in
            NavigationStack {
                InscripcionFormView(
                    inscripcionesVM: inscripcionesVM,
                    inscripcionToEdit: inscripcion,
                    cronogramaItem: displayItem,
                    curso: nil,
                    cronogramasDisponibles: agendaVM.cursosProximos.filter { $0.id != inscripcion.cronogramaId }
                )
            }
        }
        .sheet(item: $inscripcionParaPagar) { inscripcion in
            NavigationStack {
                RegistrarPagoView(
                    origen: .inscripcion(inscripcion),
                    onSave: { (pago, origen) in
                        try await inscripcionesVM.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        .sheet(item: $inscripcionAMover) { inscripcion in
            NavigationStack {
                MoverInscripcionView(
                    inscripcionesVM: inscripcionesVM,
                    inscripcion: inscripcion,
                    cronogramasDisponibles: agendaVM.cursosProximos.filter { $0.id != inscripcion.cronogramaId }
                )
            }
        }
        .onReceive(agendaVM.$cursosProximos) { items in
            if let id = cronogramaItem.id,
               let fresh = items.first(where: { $0.id == id }) {
                localItem = fresh
            }
        }
        .onReceive(agendaVM.$cursosHistoricos) { items in
            if let id = cronogramaItem.id,
               let fresh = items.first(where: { $0.id == id }) {
                localItem = fresh
            }
        }
        .onAppear {
            if let id = cronogramaItem.id {
                inscripcionesVM.fetchInscripciones(cronogramaID: id)
                // Sincronizar con el estado actual del listener al abrir la vista
                if let fresh = agendaVM.item(for: id) {
                    localItem = fresh
                }
            }
        }
        .onDisappear {
            expandedInscripcionID = nil
            inscripcionesVM.cleanupPaymentListeners()
        }
        .errorAlert($inscripcionesVM.errorMessage)
    }
}

// MARK: - Subvista para la Fila (Row)
struct InscripcionRowView: View {
    let inscripcion: Inscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    @Binding var expandedInscripcionID: String?
    @Binding var inscripcionParaPagar: Inscripcion?
    @Binding var inscripcionToEdit: Inscripcion?
    @Binding var inscripcionAMover: Inscripcion?

    @State private var showDeleteAlert = false

    var body: some View {
        Button {
            withAnimation {
                if expandedInscripcionID == inscripcion.id {
                    inscripcionesVM.stopListeningPagos(para: inscripcion)
                    expandedInscripcionID = nil
                } else {
                    expandedInscripcionID = inscripcion.id
                    inscripcionesVM.fetchPagos(para: inscripcion)
                }
            }
        } label: {
            CardView {
                HStack {
                    let ocupacion = inscripcionesVM.ocupacionPorInscripcion[inscripcion.id ?? ""] ?? 0

                    GenericRowView(
                        titulo: inscripcion.alumno_nombre,
                        subtitulo: inscripcion.notas.flatMap { $0.isEmpty ? nil : $0 },
                        infoSuperior: inscripcion.horario_inicio,
                        iconoSuperior: "clock",
                        monto: nil,
                        tags: [
                            TagConfig(text: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? "Pagado" : "Debe \(Formatters.money(inscripcion.monto_adeudado))",
                                      color: inscripcion.estado == .pagado || inscripcion.monto_adeudado <= 0 ? .green : .orange),
                            inscripcion.turnos ?? 0 > 1 ? TagConfig(text: "\(inscripcion.turnos!) turnos", color: .mint) : nil,
                            (inscripcion.cursoTipo == .taller && ocupacion > 0) ?
                                TagConfig(text: "Ocup: \(ocupacion)", color: ocupacion >= 4 ? .red : .blue) : nil
                        ].compactMap { $0 }
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expandedInscripcionID == inscripcion.id ? 90 : 0))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if inscripcion.monto_adeudado > 0 {
                Button {
                    self.inscripcionParaPagar = inscripcion
                } label: {
                    Label("Pagar", systemImage: "dollarsign.circle.fill")
                }
                .tint(.green)
            }
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

            Button {
                self.inscripcionAMover = inscripcion
            } label: {
                Label("Mover", systemImage: "arrow.right.circle.fill")
            }
            .tint(.orange)
        }
        .contextMenu {
            if inscripcion.monto_adeudado > 0 {
                Button {
                    self.inscripcionParaPagar = inscripcion
                } label: {
                    Label("Registrar Pago", systemImage: "dollarsign.circle")
                }
            }

            Button {
                self.inscripcionToEdit = inscripcion
            } label: {
                Label("Editar Inscripción", systemImage: "pencil")
            }

            Button {
                self.inscripcionAMover = inscripcion
            } label: {
                Label("Mover inscripción", systemImage: "arrow.right.circle")
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
                inscripcionesVM.deleteInscripcion(inscripcion)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminar la inscripción de \(inscripcion.alumno_nombre)? Esta acción no se puede deshacer.")
        }

        if expandedInscripcionID == inscripcion.id {
            PagosListView(inscripcion: inscripcion, inscripcionesVM: inscripcionesVM)
        }
    }
}

// MARK: - Subvista para lista de pagos (Helper)
struct PagosListView: View {
    let inscripcion: Inscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    var body: some View {
        if let id = inscripcion.id, let pagos = inscripcionesVM.pagosPorInscripcion[id] {
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
