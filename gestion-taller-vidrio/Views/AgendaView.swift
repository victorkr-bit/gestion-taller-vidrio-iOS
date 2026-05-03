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

    @State private var modoAgenda: ModoAgenda = .presenciales

    // Estado local solo para el sheet de crear
    @State private var isCreatingAgendaEvent = false
    @State private var showCalendario = false
    @State private var itemToDelete: CronogramaItem?
    @State private var showDeleteAlert = false
    @State private var itemToEdit: CronogramaItem?

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
                        itemToEdit: $itemToEdit,
                        itemToDelete: $itemToDelete,
                        showDeleteAlert: $showDeleteAlert
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
                        HStack {
                            Button("Calendario", systemImage: "calendar") {
                                showCalendario = true
                            }
                            Button("Nuevo evento", systemImage: "plus") {
                                self.isCreatingAgendaEvent = true
                            }
                        }
                    }
                }
            }
            // Sheet para crear evento
            .sheet(isPresented: $isCreatingAgendaEvent) {
                NavigationStack { AgendaFormView(agendaVM: agendaVM) }
            }
            .sheet(isPresented: $showCalendario) {
                CalendarioAgendaView(items: agendaVM.cursosProximos)
            }
            .sheet(item: $itemToEdit) { item in
                NavigationStack {
                    EditarAgendaView(agendaVM: agendaVM, cronogramaItem: item)
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
                    agendaVM.fetchCronograma()
                case .online:
                    catalogoOnlineVM.subscribeToCatalogoOnline()
                case .historial:
                    agendaVM.filtroSeleccionado = .historial
                    catalogoOnlineVM.stopListening()
                    agendaVM.fetchCronograma()
                }
            }
            .navigationDestination(for: CronogramaItem.self) { item in
                AgendaDetailView(agendaVM: agendaVM, inscripcionesVM: inscripcionesVM, cronogramaItem: item)
            }
        }
    }

}
