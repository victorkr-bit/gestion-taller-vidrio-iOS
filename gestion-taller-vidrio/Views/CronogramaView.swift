import SwiftUI

struct CronogramaView: View {
    // RECIBIMOS el VM (Inyección de dependencias), NO lo creamos aquí
    @ObservedObject var viewModel: CronogramaViewModel
    
    // Acceso al NavigationManager global
    @EnvironmentObject var navManager: NavigationManager
    
    // Estado local solo para el sheet de crear
    @State private var isCreatingAgendaEvent = false
    
    var body: some View {
        // VINCULAMOS EL PATH DEL MANAGER AQUÍ
        NavigationStack(path: $navManager.cronogramaPath) {
            VStack(spacing: 0) {
                
                // --- Selector de Modo (Agenda vs Online) ---
                Picker("Modo de Vista", selection: $viewModel.modoVista.animation()) {
                    ForEach(CronogramaViewModel.ModoVista.allCases) { modo in
                        Text(modo.rawValue).tag(modo)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // --- Contenido dinámico según el modo ---
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
                // Toolbar solo si estamos en modo Agenda
                if viewModel.modoVista == .agenda {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { self.isCreatingAgendaEvent = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Sheet para crear evento
            .sheet(isPresented: $isCreatingAgendaEvent) {
                NavigationStack { CronogramaFormView(viewModel: viewModel) }
            }
            // Alertas de error
            .alert("Atención", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            })
            // Recarga al cambiar pestaña
            .onChange(of: viewModel.modoVista) { _, newMode in
                if newMode == .online {
                    viewModel.subscribeToCatalogoOnline()
                } else {
                    viewModel.fetchCronograma()
                }
            }
            // --- AQUÍ OCURRE LA MAGIA DE LA NAVEGACIÓN ---
            // Cuando el NavigationManager añade un 'CronogramaItem' al path,
            // esta función lo atrapa y empuja la vista de detalle.
            .navigationDestination(for: CronogramaItem.self) { item in
                CronogramaDetailView(viewModel: viewModel, cronogramaItem: item)
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
                // En CronogramaView.swift -> agendaListView

                List {
                    ForEach(viewModel.cursosFiltrados) { item in
                        
                        // --- CAMBIO: Reemplazamos NavigationLink por Button ---
                        Button {
                            // Acción imperativa: Añadimos manual al path global
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
                        // Estilos necesarios para que el botón en la lista se vea bien
                        .listRowSeparator(.hidden)
                        .buttonStyle(.plain) // Evita que se ilumine toda la celda azul feo
                        
                        // --- FIN DEL CAMBIO ---
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
                .refreshable { viewModel.subscribeToCatalogoOnline() }
            }
        }
    }
}
