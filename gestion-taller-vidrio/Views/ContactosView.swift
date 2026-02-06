import SwiftUI

struct ContactosView: View {
    
    @StateObject private var viewModel = ContactosViewModel()
    
    @State private var contactToEdit: Contacto?
    @State private var isCreatingNew = false
    @State private var contactoToDelete: Contacto?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Usamos contactosFiltrados para decidir si mostrar loading o empty state
                if viewModel.isLoading && viewModel.contactos.isEmpty {
                    ProgressView("Cargando contactos...")
                } else {
                    List {
                        ForEach(viewModel.contactosFiltrados) { contacto in
                            Button {
                                self.contactToEdit = contacto
                            } label: {
                                CardView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(contacto.nombreCompleto)
                                            .font(.headline)
                                            .foregroundStyle(Color.primary)
                                        
                                        if let telefono = contacto.telefono, !telefono.isEmpty {
                                            HStack {
                                                Image(systemName: "phone.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondary)
                                                Text(telefono)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.secondary)
                                            }
                                        }
                                        
                                        if let email = contacto.email, !email.isEmpty {
                                            HStack {
                                                Image(systemName: "envelope.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondary)
                                                Text(email)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                contactoToDelete = viewModel.contactosFiltrados[index]
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.fetchContactos()
                    }
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .always), // Opcional: para que siempre se vea
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
                    ContactoFormView(
                        viewModel: viewModel,
                        contactoToEdit: nil
                    )
                }
            }
            .sheet(item: $contactToEdit) { contact in
                NavigationStack {
                    ContactoFormView(
                        viewModel: viewModel,
                        contactoToEdit: contact
                    )
                }
            }
            .errorAlert($viewModel.errorMessage)
            .alert("Eliminar Contacto", isPresented: Binding<Bool>(
                get: { contactoToDelete != nil },
                set: { if !$0 { contactoToDelete = nil } }
            )) {
                Button("Eliminar", role: .destructive) {
                    if let contacto = contactoToDelete, let index = viewModel.contactosFiltrados.firstIndex(where: { $0.id == contacto.id }) {
                        viewModel.deleteContacto(at: IndexSet(integer: index))
                    }
                    contactoToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    contactoToDelete = nil
                }
            } message: {
                Text("¿Eliminar a \"\(contactoToDelete?.nombreCompleto ?? "")\"? Esta acción no se puede deshacer.")
            }
        }
    }
}
