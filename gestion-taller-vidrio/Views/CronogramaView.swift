import SwiftUI

struct CronogramaView: View {
    @StateObject private var viewModel = CronogramaViewModel()
    @State private var isCreatingAgendaEvent = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selector de Modo
                Picker("Modo de Vista", selection: $viewModel.modoVista.animation()) {
                    ForEach(CronogramaViewModel.ModoVista.allCases) { modo in
                        Text(modo.rawValue).tag(modo)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewModel.modoVista == .agenda {
                    // --- MODO AGENDA ---
                    // Filtro Próximos / Historial
                    Picker("Filtro Cronograma", selection: $viewModel.filtroSeleccionado.animation()) {
                        ForEach(CronogramaViewModel.FiltroCronograma.allCases) { filtro in
                            Text(filtro.rawValue).tag(filtro)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    agendaListView
                    
                } else {
                    // --- MODO ONLINE ---
                    onlineListView
                }
            }
            .navigationTitle("Gestión Taller")
            .toolbar {
                if viewModel.modoVista == .agenda {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { self.isCreatingAgendaEvent = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isCreatingAgendaEvent) {
                NavigationStack { CronogramaFormView(viewModel: viewModel) }
            }
            .alert("Atención", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            })
            
            // Lógica de recarga al cambiar de pestaña
            .onChange(of: viewModel.modoVista) { _, newMode in
                if newMode == .online {
                    viewModel.subscribeToCatalogoOnline()
                } else {
                    // Si vuelve a agenda, refrescamos el historial por si acaso
                    viewModel.fetchCronograma()
                }
            }
        }
    }
    
    // MARK: - Subvistas de Listas
    
    /// Vista de la lista para la Agenda (Talleres y Cursos con Fecha)
    private var agendaListView: some View {
            ZStack {
                if viewModel.isLoading && viewModel.cursosFiltrados.isEmpty {
                    ProgressView("Cargando agenda...")
                } else if viewModel.cursosFiltrados.isEmpty {
                    ContentUnavailableView("No hay eventos", systemImage: "calendar.badge.exclamationmark")
                } else {
                    List {
                        ForEach(viewModel.cursosFiltrados) { item in
                            NavigationLink {
                                CronogramaDetailView(viewModel: viewModel, cronogramaItem: item)
                            } label: {
                                CardView {
                                    // CORRECCIÓN MAESTRA: Usamos GenericRowView
                                    GenericRowView(
                                        titulo: item.cursoNombre,
                                            subtitulo: nil,
                                            infoSuperior: Formatters.date(item.fecha),        // Solo la Fecha
                                            infoSuperiorSecundaria: Formatters.time(item.fecha), // La Hora va aquí
                                            iconoSuperior: "calendar",
                                            monto: item.precio_curso,
                                        tags: [
                                            // Tag de Inscriptos
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
                            // Swipe Actions si corresponde...
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                viewModel.deleteCronogramaItem(viewModel.cursosFiltrados[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.fetchCronograma() }
                }
            }
        }
    
    /// Vista de la lista para Cursos Online (Productos Evergreen)
    private var onlineListView: some View {
            ZStack {
                if viewModel.catalogoOnline.isEmpty && viewModel.isLoading {
                    ProgressView()
                } else if viewModel.catalogoOnline.isEmpty {
                    ContentUnavailableView("Sin catálogo", systemImage: "globe")
                } else {
                    List {
                        ForEach(viewModel.catalogoOnline) { curso in
                            NavigationLink {
                                OnlineCourseDetailView(viewModel: viewModel, curso: curso)
                            } label: {
                                CardView {
                                    // CORRECCIÓN MAESTRA: Usamos GenericRowView para Online también
                                    GenericRowView(
                                        titulo: curso.nombre,
                                        subtitulo: curso.tipo.descripcion.uppercased(),
                                        infoSuperior: nil, // Online no tiene fecha
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
                    .refreshable { viewModel.subscribeToCatalogoOnline() }
                }
            }
        }
}

