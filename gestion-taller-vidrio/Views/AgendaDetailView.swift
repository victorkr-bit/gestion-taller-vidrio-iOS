import SwiftUI
import Charts

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

    private var datosOcupacion: [OcupacionHoraDato] {
        TallerCalculator.calcularOcupacionPorHora(para: inscripcionesVM.inscripciones)
    }

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
                                    .bold()
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
                                            .font(.headline).bold()
                                        Text("inscriptos")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .center, spacing: 2) {
                                        Text(Formatters.money(totalAbonado))
                                            .font(.headline).fontWeight(.semibold).foregroundStyle(DesignSystem.Color.exito)
                                        Text("cobrado")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .center, spacing: 2) {
                                        Text(Formatters.money(totalAdeudado))
                                            .font(.headline).fontWeight(.semibold)
                                            .foregroundStyle(totalAdeudado > 0 ? DesignSystem.Color.alerta : Color.secondary)
                                        Text("adeudado")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    // --- Sección 2: Gráfico de Ocupación (solo para talleres) ---
                    if displayItem.cursoTipo == .taller && !inscripcionesVM.inscripciones.isEmpty {
                        Section {
                            TallerOcupacionChart(datos: datosOcupacion)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        .listRowSeparator(.hidden)
                    }

                    // --- Sección 3: Lista de Inscriptos ---
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
                    curso: nil
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

// MARK: - Gráfico de Ocupación

private struct TallerOcupacionChart: View {
    let datos: [OcupacionHoraDato]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ocupación por hora")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Espaciado.m)

            Chart(datos) { dato in
                BarMark(
                    x: .value("Hora", dato.horaString),
                    y: .value("Cantidad", dato.cantidad)
                )
                .foregroundStyle(DesignSystem.Color.accion.gradient)
                .cornerRadius(DesignSystem.Radio.grafico)
                .annotation(position: .top) {
                    if dato.cantidad > 0 {
                        Text("\(dato.cantidad)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 120)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...5)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Espaciado.m)
            .padding(.bottom, DesignSystem.Espaciado.sm)
        }
        .padding(.vertical, DesignSystem.Espaciado.sm)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
        .sombraTarjeta(DesignSystem.Sombra.panel)
        .padding(.horizontal, DesignSystem.Espaciado.m)
    }
}
