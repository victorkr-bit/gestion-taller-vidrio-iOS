import SwiftUI

struct ContactosView: View {
    
    @StateObject private var viewModel = ContactosViewModel()
    
    @State private var contactToEdit: Contacto?
    @State private var isCreatingNew = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Usamos contactosFiltrados para decidir si mostrar loading o empty state
                if viewModel.isLoading && viewModel.contactos.isEmpty {
                    ProgressView("Cargando contactos...")
                } else {
                    List {
                        // --- CAMBIO CLAVE: Iteramos sobre la lista filtrada ---
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
                        .onDelete(perform: viewModel.deleteContacto)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.fetchContactos()
                    }
                    // --- NUEVO: Modificador de búsqueda ---
                    // Esto inyecta la barra nativa de iOS arriba de todo
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .always), // Opcional: para que siempre se vea
                        prompt: "Buscar contacto"
                    )
                    // Opcional: Mostrar mensaje si no hay resultados en la búsqueda
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
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error desconocido.")
            })
        }
    }
}
