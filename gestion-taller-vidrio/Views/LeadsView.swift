import SwiftUI
import UIKit  // UIPasteboard

struct LeadsView: View {
    @ObservedObject var viewModel: LeadsViewModel
    let inscripcionesVM: InscripcionesViewModel

    @State private var leadsSeleccionados: Set<String> = []
    @State private var showNotificacionSheet = false
    @State private var leadParaConvertir: Lead? = nil
    @State private var pendingAlumnoId: String? = nil
    @State private var pendingAlumnoNombre: String? = nil
    @State private var showInscripcionSheet = false
    @State private var leadParaBorrar: Lead? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.m) {

                // Buscador
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar por nombre o curso", text: $viewModel.filtroTexto)
                        .autocorrectionDisabled()
                }
                .padding(DesignSystem.Espaciado.sm)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
                .padding(.horizontal, DesignSystem.Espaciado.l)

                // Filtro de estado
                Picker("Estado", selection: $viewModel.filtroEstado) {
                    Text("Todos").tag(Optional<EstadoLead>.none)
                    ForEach(EstadoLead.allCases, id: \.self) { estado in
                        Text(estado.label).tag(Optional(estado))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Espaciado.l)

                // Lista de leads
                if viewModel.leadsFiltrados.isEmpty {
                    EstadoVacioView(
                        icono: "person.badge.plus",
                        mensaje: viewModel.filtroTexto.isEmpty && viewModel.filtroEstado == nil
                            ? "No hay leads registrados"
                            : "No hay resultados para el filtro actual"
                    )
                    .padding(.top, DesignSystem.Espaciado.xl)
                } else {
                    LazyVStack(spacing: DesignSystem.Espaciado.sm) {
                        ForEach(viewModel.leadsFiltrados) { lead in
                            LeadRowView(
                                lead: lead,
                                isSelected: seleccionBinding(for: lead),
                                onMarcarNotificado: {
                                    viewModel.marcarNotificado(leads: [lead])
                                },
                                onConvertir: {
                                    leadParaConvertir = lead
                                },
                                onCrearInscripcion: {
                                    pendingAlumnoId = lead.contacto_id
                                    pendingAlumnoNombre = lead.nombre
                                    showInscripcionSheet = true
                                },
                                onBorrar: {
                                    leadParaBorrar = lead
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Espaciado.l)
                }
            }
            .padding(.vertical, DesignSystem.Espaciado.m)
        }
        .navigationTitle("Leads")
        .toolbar {
            if !leadsSeleccionados.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Notificar (\(leadsSeleccionados.count))") {
                        showNotificacionSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .sheet(isPresented: $showNotificacionSheet) {
            PanelNotificacionView(
                leads: viewModel.leads.filter { leadsSeleccionados.contains($0.id ?? "") },
                cronograma: viewModel.cronogramaProximos,
                onMarcarNotificados: { leads in
                    viewModel.marcarNotificado(leads: leads)
                    leadsSeleccionados.removeAll()
                    showNotificacionSheet = false
                }
            )
        }
        .onChange(of: showNotificacionSheet) { _, isShowing in
            if isShowing { viewModel.fetchCronogramaProximos() }
        }
        .sheet(item: $leadParaConvertir) { lead in
            ModalConversionView(lead: lead, viewModel: viewModel)
        }
        .sheet(isPresented: $showInscripcionSheet) {
            NavigationStack {
                InscripcionFormView(
                    inscripcionesVM: inscripcionesVM,
                    preselectedAlumnoId: pendingAlumnoId,
                    preselectedAlumnoNombre: pendingAlumnoNombre
                )
            }
        }
        .alert("Borrar lead", isPresented: Binding(
            get: { leadParaBorrar != nil },
            set: { if !$0 { leadParaBorrar = nil } }
        )) {
            Button("Borrar", role: .destructive) {
                if let lead = leadParaBorrar {
                    viewModel.borrarLead(lead)
                }
                leadParaBorrar = nil
            }
            Button("Cancelar", role: .cancel) { leadParaBorrar = nil }
        } message: {
            if let lead = leadParaBorrar {
                Text("¿Borrar a \(lead.nombre)? Esta acción no se puede deshacer.")
            }
        }
        .errorAlert($viewModel.errorMessage)
    }

    private func seleccionBinding(for lead: Lead) -> Binding<Bool> {
        guard let id = lead.id else { return .constant(false) }
        return Binding(
            get: { leadsSeleccionados.contains(id) },
            set: { isOn in
                if isOn { leadsSeleccionados.insert(id) }
                else { leadsSeleccionados.remove(id) }
            }
        )
    }
}

// MARK: - Panel de Notificación

private struct PanelNotificacionView: View {
    let leads: [Lead]
    let cronograma: [CronogramaItem]
    let onMarcarNotificados: ([Lead]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var plantilla: String
    @State private var eventoSeleccionadoId: String = ""
    @State private var ultimoCopiado: String? = nil

    init(leads: [Lead], cronograma: [CronogramaItem], onMarcarNotificados: @escaping ([Lead]) -> Void) {
        self.leads = leads
        self.cronograma = cronograma
        self.onMarcarNotificados = onMarcarNotificados
        let primerNombre = leads.first.map {
            String($0.nombre.split(separator: " ").first ?? Substring($0.nombre))
        } ?? "[nombre]"
        _plantilla = State(initialValue: "¡Hola \(primerNombre)! Te escribimos del Taller porque tenemos novedades sobre el curso que te interesó. ¿Seguís con ganas de sumarte?")
    }

    private var eventoSeleccionado: CronogramaItem? {
        cronograma.first { $0.id == eventoSeleccionadoId }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Selector de evento
                Section {
                    Picker("Asociar evento", selection: $eventoSeleccionadoId) {
                        Text("Sin evento específico").tag("")
                        ForEach(cronograma, id: \.id) { item in
                            Text("\(item.cursoNombre) — \(Formatters.date(item.fecha))")
                                .tag(item.id ?? "")
                        }
                    }
                }

                // Mensaje editable
                Section("Mensaje editable") {
                    TextEditor(text: $plantilla)
                        .frame(minHeight: 90)
                }

                // Lista de leads (sin título)
                Section {
                    ForEach(leads) { lead in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lead.nombre)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let url = chatURL(for: lead) {
                                    Link(destination: url) {
                                        HStack(spacing: 0) {
                                            Text(lead.canal.capitalized + " · ")
                                                .foregroundStyle(.secondary)
                                            Text(lead.contacto)
                                        }
                                    }
                                    .font(.caption)
                                } else {
                                    Text(lead.canal.capitalized + " · " + lead.contacto)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                copiarMensaje(para: lead)
                            } label: {
                                Label(
                                    ultimoCopiado == lead.id ? "Copiado" : "Copiar",
                                    systemImage: ultimoCopiado == lead.id ? "checkmark" : "doc.on.doc"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(ultimoCopiado == lead.id ? DesignSystem.Color.exito : DesignSystem.Color.accion)
                            .controlSize(.small)
                        }
                        .padding(.vertical, DesignSystem.Espaciado.xs)
                    }
                }

                Section {
                    Button("Marcar todos como notificados") {
                        onMarcarNotificados(leads)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(DesignSystem.Color.accion)
                }
            }
            .navigationTitle("Notificar leads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onChange(of: eventoSeleccionadoId) { _, _ in
                actualizarPlantilla()
            }
        }
    }

    private func actualizarPlantilla() {
        let primerNombre = leads.first.map {
            String($0.nombre.split(separator: " ").first ?? Substring($0.nombre))
        } ?? "[nombre]"

        if let evento = eventoSeleccionado {
            let fecha = Formatters.date(evento.fecha)
            plantilla = "¡Hola \(primerNombre)! Te escribimos del Taller porque tenemos novedades sobre el curso que te interesó. Tenemos clase de \(evento.cursoNombre) el \(fecha). ¿Te anotamos?"
        } else {
            plantilla = "¡Hola \(primerNombre)! Te escribimos del Taller porque tenemos novedades sobre el curso que te interesó. ¿Seguís con ganas de sumarte?"
        }
    }

    private func copiarMensaje(para lead: Lead) {
        let primerNombre = String(lead.nombre.split(separator: " ").first ?? Substring(lead.nombre))
        let mensaje = plantilla.replacingOccurrences(of: "[nombre]", with: primerNombre)
        UIPasteboard.general.string = mensaje
        ultimoCopiado = lead.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if ultimoCopiado == lead.id { ultimoCopiado = nil }
        }
    }

    private func chatURL(for lead: Lead) -> URL? {
        let canalLower = lead.canal.lowercased()
        if canalLower.contains("instagram") {
            return URL(string: "https://www.instagram.com/\(lead.contacto)")
        } else if canalLower.contains("whatsapp") {
            let digits = lead.contacto.filter(\.isNumber)
            return URL(string: "https://wa.me/\(digits)")
        }
        return nil
    }
}

// MARK: - Modal de Conversión

private struct ModalConversionView: View {
    let lead: Lead
    @ObservedObject var viewModel: LeadsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isConvirtiendo = false
    @State private var convertidoExitosamente = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del lead") {
                    LabeledContent("Nombre", value: lead.nombre)
                    LabeledContent("Canal", value: lead.canal)
                    LabeledContent("Contacto", value: lead.contacto)
                    LabeledContent("Interés", value: lead.curso_interes)
                    if !lead.notas.isEmpty {
                        LabeledContent("Notas", value: lead.notas)
                    }
                }

                Section {
                    if convertidoExitosamente {
                        Label("Convertido exitosamente", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.Color.exito)
                            .frame(maxWidth: .infinity)
                    } else {
                        BotonPrimario(
                            titulo: "Confirmar conversión",
                            accion: {
                                Task {
                                    isConvirtiendo = true
                                    do {
                                        _ = try await viewModel.convertirLead(lead)
                                        convertidoExitosamente = true
                                        try? await Task.sleep(nanoseconds: 800_000_000)
                                        dismiss()
                                    } catch {
                                        errorMessage = FirestoreManager.mensajeAmigable(error)
                                    }
                                    isConvirtiendo = false
                                }
                            },
                            estaCargando: isConvirtiendo
                        )
                    }
                }
            }
            .navigationTitle("Convertir lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .errorAlert($errorMessage)
        }
    }
}
