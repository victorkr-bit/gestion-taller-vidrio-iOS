import SwiftUI

struct ContactosView: View {

    @StateObject private var viewModel: ContactosViewModel
    let detailVM: ContactoDetailViewModel

    init(contactosRepo: any ContactosRepositorio, tallerRepo: any TallerRepositorio, detailVM: ContactoDetailViewModel) {
        _viewModel = StateObject(wrappedValue: ContactosViewModel(repository: contactosRepo, tallerRepo: tallerRepo))
        self.detailVM = detailVM
    }

    @State private var isCreatingNew = false
    @State private var contactoToDelete: Contacto?
    @State private var contactoToEdit: Contacto?

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.contactos.isEmpty {
                ProgressView("Cargando contactos...")
            } else {
                List {
                    ForEach(viewModel.contactosFiltrados) { contacto in
                        NavigationLink(destination: ContactoDetailView(contacto: contacto, detailVM: detailVM, contactosVM: viewModel)) {
                            CardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(contacto.nombreCompleto)
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)

                                    if let telefono = contacto.telefono, !telefono.isEmpty {
                                        HStack {
                                            Image(systemName: "phone.fill")
                                                .font(.caption)
                                                .foregroundStyle(DesignSystem.Color.accion)
                                            Text(telefono)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.primary)
                                        }
                                    }

                                    if let email = contacto.email, !email.isEmpty {
                                        HStack {
                                            Image(systemName: "envelope.fill")
                                                .font(.caption)
                                                .foregroundStyle(DesignSystem.Color.accion)
                                            Text(email)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.primary)
                                        }
                                    }
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button {
                                contactoToEdit = contacto
                            } label: {
                                Label("Editar Contacto", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                Task {
                                    await viewModel.cargarInscripcionesParaEliminar(contacto: contacto)
                                    contactoToDelete = contacto
                                }
                            } label: {
                                Label("Eliminar Contacto", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            let contacto = viewModel.contactosFiltrados[index]
                            Task {
                                await viewModel.cargarInscripcionesParaEliminar(contacto: contacto)
                                contactoToDelete = contacto
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewModel.fetchContactos()
                }
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Buscar contacto"
                )
                .overlay {
                    if viewModel.contactosFiltrados.isEmpty && !viewModel.searchText.isEmpty {
                        ContentUnavailableView(
                            "No se encontraron resultados",
                            systemImage: "magnifyingglass",
                            description: Text("Intenta con otro nombre.")
                        )
                    }
                }
            }
        }
        .navigationTitle("Contactos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.isCreatingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                ContactoFormView(
                    viewModel: viewModel,
                    contactoToEdit: nil
                )
            }
        }
        .sheet(item: $contactoToEdit) { contacto in
            NavigationStack {
                ContactoFormView(viewModel: viewModel, contactoToEdit: contacto)
            }
        }
        .errorAlert($viewModel.errorMessage)
        .alert("Eliminar Contacto", isPresented: Binding<Bool>(
            get: { contactoToDelete != nil },
            set: { if !$0 { contactoToDelete = nil; viewModel.limpiarEstadoEliminacion() } }
        )) {
            Button(viewModel.inscripcionesAlEliminar.isEmpty ? "Eliminar" : "Eliminar de todas formas",
                   role: .destructive) {
                if let contacto = contactoToDelete, let index = viewModel.contactosFiltrados.firstIndex(where: { $0.id == contacto.id }) {
                    viewModel.deleteContacto(at: IndexSet(integer: index))
                }
                contactoToDelete = nil
            }
            Button("Cancelar", role: .cancel) {
                contactoToDelete = nil
                viewModel.limpiarEstadoEliminacion()
            }
        } message: {
            let nombre = contactoToDelete?.nombreCompleto ?? ""
            let count = viewModel.inscripcionesAlEliminar.count
            if count == 0 {
                Text("¿Eliminar a \"\(nombre)\"? Esta acción no se puede deshacer.")
            } else {
                Text("¿Eliminar a \"\(nombre)\"? Este contacto tiene \(count) inscripción\(count == 1 ? "" : "es") en cursos. Esta acción no se puede deshacer.")
            }
        }
    }
}

#if DEBUG
#Preview {
    let c = PreviewContainer.shared
    NavigationStack {
        ContactosView(contactosRepo: c.contactosRepo, tallerRepo: c.tallerRepo, detailVM: c.contactoDetailVM)
    }
    .environmentObject(NavigationManager())
}
#endif
