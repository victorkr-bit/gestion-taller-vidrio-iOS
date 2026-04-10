import SwiftUI

enum ModoAgenda: String, CaseIterable, Identifiable {
    case presenciales = "Presenciales"
    case online = "Online"
    case historial = "Historial"
    var id: String { self.rawValue }
}

struct CronogramaView: View {
    @ObservedObject var agendaVM: AgendaViewModel
    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    @ObservedObject var catalogoOnlineVM: CatalogoOnlineViewModel

    // Acceso al NavigationManager global
    @EnvironmentObject var navManager: NavigationManager

    @State private var modoAgenda: ModoAgenda = .presenciales

    // Estado local solo para el sheet de crear
    @State private var isCreatingAgendaEvent = false
    @State private var itemToDelete: CronogramaItem?
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
                case .presenciales:
                    agendaListView
                case .online:
                    onlineListView
                case .historial:
                    agendaListView
                }
            }
            .navigationTitle("Agenda de Cursos")
            .toolbar {
                if modoAgenda == .presenciales {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { self.isCreatingAgendaEvent = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Sheet para crear evento
            .sheet(isPresented: $isCreatingAgendaEvent) {
                NavigationStack { CronogramaFormView(agendaVM: agendaVM) }
            }
            .sheet(item: $itemToEdit) { item in
                NavigationStack {
                    EditarCronogramaView(agendaVM: agendaVM, cronogramaItem: item)
                }
            }
            .errorAlert(activeErrorMessage)
            .alert("Eliminar Evento", isPresented: Binding<Bool>(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            )) {
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
                Text("¿Eliminar \"\(itemToDelete?.cursoNombre ?? "")\"? Esta acción no se puede deshacer.")
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
                CronogramaDetailView(agendaVM: agendaVM, inscripcionesVM: inscripcionesVM, cronogramaItem: item)
            }
        }
    }

    // MARK: - Subvistas de Listas

    /// Vista de la lista para Presenciales e Historial
    private var agendaListView: some View {
        ZStack {
            if agendaVM.isLoading && agendaVM.cursosFiltrados.isEmpty {
                ProgressView("Cargando agenda...")
            } else if agendaVM.cursosFiltrados.isEmpty {
                ContentUnavailableView("No hay eventos", systemImage: "calendar.badge.exclamationmark")
            } else {
                List {
                    ForEach(agendaVM.cursosFiltrados) { item in
                        Button {
                            navManager.cronogramaPath.append(item)
                        } label: {
                            CardView {
                                GenericRowView(
                                    titulo: item.cursoNombre,
                                    subtitulo: nil,
                                    infoSuperior: Formatters.date(item.fecha),
                                    infoSuperiorSecundaria: Formatters.time(item.fecha),
                                    iconoSuperior: "calendar",
                                    monto: item.precio_curso,
                                    tags: [
                                        TagConfig(
                                            text: "Alumnos (\(item.inscriptosReales))",
                                            color: item.inscriptosReales > 0 ? .blue : .gray
                                        )
                                    ]
                                )
                            }
                        }
                        .listRowSeparator(.hidden)
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Editar Curso", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                itemToDelete = item
                            } label: {
                                Label("Eliminar Curso", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                            } label: {
                                Label("Borrar", systemImage: "trash.fill")
                            }
                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { agendaVM.fetchCronograma() }
            }
        }
    }

    /// Vista de la lista para Cursos Online (Productos Evergreen)
    private var onlineListView: some View {
        ZStack {
            if catalogoOnlineVM.catalogoOnline.isEmpty && catalogoOnlineVM.isLoading {
                ProgressView()
            } else if catalogoOnlineVM.catalogoOnline.isEmpty {
                ContentUnavailableView("Sin catálogo", systemImage: "globe")
            } else {
                List {
                    ForEach(catalogoOnlineVM.catalogoOnline) { curso in
                        NavigationLink {
                            OnlineCourseDetailView(inscripcionesVM: inscripcionesVM, curso: curso)
                        } label: {
                            CardView {
                                GenericRowView(
                                    titulo: curso.nombre,
                                    subtitulo: curso.tipo.descripcion.uppercased(),
                                    infoSuperior: nil,
                                    iconoSuperior: nil,
                                    monto: curso.precio,
                                    tags: [
                                        TagConfig(text: "Alumnos (\(curso.inscriptosTotales))", color: .purple)
                                    ]
                                )
                            }
                        }
                        .listRowSeparator(.hidden)
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .refreshable { catalogoOnlineVM.subscribeToCatalogoOnline() }
            }
        }
    }
}
