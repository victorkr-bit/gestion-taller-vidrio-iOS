import SwiftUI

enum ModoAgenda: String, CaseIterable, Identifiable {
    case presenciales = "Presenciales"
    case online = "Online"
    case historial = "Historial"
    var id: String { self.rawValue }
}

struct AgendaView: View {
    @ObservedObject var agendaVM: AgendaViewModel
    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    @ObservedObject var catalogoOnlineVM: CatalogoOnlineViewModel

    // Acceso al NavigationManager global
    @EnvironmentObject var navManager: NavigationManager

    @Environment(\.scenePhase) private var scenePhase

    @State private var modoAgenda: ModoAgenda = .presenciales

    // Estado local solo para el sheet de crear
    @State private var isCreatingAgendaEvent = false
    @State private var showCalendario = false
    @State private var itemToDelete: CronogramaItem?
    @State private var showDeleteAlert = false
    @State private var itemToEdit: CronogramaItem?
    @State private var itemToMover: CronogramaItem?

    private var activeErrorMessage: Binding<String?> {
        modoAgenda == .online ? $catalogoOnlineVM.errorMessage : $agendaVM.errorMessage
    }

    var body: some View {
        NavigationStack(path: $navManager.cronogramaPath) {
            VStack(spacing: 0) {

                // --- Selector de Modo ---
                Picker("Modo", selection: $modoAgenda.animation()) {
                    ForEach(ModoAgenda.allCases) { modo in
                        Text(modo.rawValue).tag(modo)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // --- Contenido dinámico según el modo ---
                switch modoAgenda {
                case .presenciales, .historial:
                    AgendaListView(
                        agendaVM: agendaVM,
                        inscripcionesVM: inscripcionesVM,
                        itemToEdit: $itemToEdit,
                        itemToDelete: $itemToDelete,
                        showDeleteAlert: $showDeleteAlert,
                        itemToMover: $itemToMover
                    )
                case .online:
                    OnlineListView(
                        catalogoOnlineVM: catalogoOnlineVM,
                        inscripcionesVM: inscripcionesVM
                    )
                }
            }
            .navigationTitle("Agenda de Cursos")
            .toolbar {
                if modoAgenda == .presenciales {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Nuevo evento", systemImage: "plus") {
                            self.isCreatingAgendaEvent = true
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Calendario", systemImage: "calendar") {
                            showCalendario = true
                        }
                    }
                }
            }
            // Sheet para crear evento
            .sheet(isPresented: $isCreatingAgendaEvent) {
                NavigationStack { AgendaFormView(agendaVM: agendaVM) }
            }
            .sheet(isPresented: $showCalendario) {
                CalendarioAgendaView(
                    items: agendaVM.cursosProximos,
                    feriados: agendaVM.feriadosCalendario,
                    fiestasJudias: agendaVM.fiestasJudias,
                    onSeleccionarItem: { item in
                        // Ya estamos en la tab de cronograma (el calendario se abre desde
                        // Agenda), así que append directo sin el defer de navigateToCourseDetail.
                        // El push arranca junto al cierre del sheet → menos glimpse de la lista.
                        showCalendario = false
                        navManager.cronogramaPath.append(item)
                    }
                )
            }
            .onChange(of: showCalendario) { _, isShowing in
                if isShowing { Task { await agendaVM.fetchFeriadosIfNeeded() } }
            }
            .sheet(item: $itemToEdit) { item in
                NavigationStack {
                    EditarAgendaView(agendaVM: agendaVM, cronogramaItem: item)
                }
            }
            .sheet(item: $itemToMover) { item in
                NavigationStack {
                    MoverCronogramaView(agendaVM: agendaVM, item: item)
                }
            }
            .errorAlert(activeErrorMessage)
            .alert("Eliminar Evento", isPresented: $showDeleteAlert) {
                Button("Eliminar", role: .destructive) {
                    if let item = itemToDelete {
                        agendaVM.deleteCronogramaItem(item)
                    }
                    itemToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    itemToDelete = nil
                }
            } message: {
                if let nombre = itemToDelete?.cursoNombre {
                    Text("¿Eliminar \"\(nombre)\"? Esta acción no se puede deshacer.")
                }
            }
            .onChange(of: modoAgenda) { _, newMode in
                switch newMode {
                case .presenciales:
                    agendaVM.filtroSeleccionado = .proximos
                    catalogoOnlineVM.stopListening()
                    inscripcionesVM.subscribeToPreinscriptosGlobal()
                    if agendaVM.cursosHistoricos.isEmpty { agendaVM.fetchCronograma() }
                case .online:
                    inscripcionesVM.unsubscribeFromPreinscriptosGlobal()
                    catalogoOnlineVM.subscribeToCatalogoOnline()
                case .historial:
                    agendaVM.filtroSeleccionado = .historial
                    catalogoOnlineVM.stopListening()
                    inscripcionesVM.subscribeToPreinscriptosGlobal()
                    if agendaVM.cursosHistoricos.isEmpty { agendaVM.fetchCronograma() }
                }
            }
            .onAppear {
                agendaVM.refrescarSiCambioDia()
                if modoAgenda != .online {
                    inscripcionesVM.subscribeToPreinscriptosGlobal()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    agendaVM.refrescarSiCambioDia()
                }
            }
            .onDisappear {
                inscripcionesVM.unsubscribeFromPreinscriptosGlobal()
            }
            .navigationDestination(for: CronogramaItem.self) { item in
                AgendaDetailView(agendaVM: agendaVM, inscripcionesVM: inscripcionesVM, cronogramaItem: item)
            }
        }
    }

}
