import SwiftUI

struct CursosView: View {
    
    @StateObject private var viewModel = CursosViewModel()
    
    // --- CAMBIO 1: Estados separados ---
    // 'cursoToEdit' activa el sheet de EDICIÓN
    @State private var cursoToEdit: Curso?
    // 'isCreatingNew' activa el sheet de CREACIÓN
    @State private var isCreatingNew = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.cursos.isEmpty {
                    ProgressView("Cargando cursos...")
                } else {
                    List {
                        ForEach(viewModel.cursos) { curso in
                            // Usamos un Button para la acción explícita
                            Button {
                                // --- CAMBIO 2: Lógica de EDICIÓN ---
                                // Esto activa el sheet(item: $cursoToEdit)
                                self.cursoToEdit = curso
                            } label: {
                                CardView {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(curso.nombre)
                                                .font(.headline)
                                                .foregroundStyle(Color.primary)
                                            
                                            Text(curso.tipo.descripcion)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.secondary)
                                                .padding(4)
                                                .background(Color.secondary.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(Formatters.money(curso.precio))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                            .buttonStyle(.plain) // Mantiene el estilo de la card
                        }
                        .onDelete(perform: viewModel.deleteCurso)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.fetchCursos()
                    }
                }
            }
            .navigationTitle("Catálogo de Cursos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // --- CAMBIO 3: Lógica de CREACIÓN ---
                        // Esto activa el sheet(isPresented: $isCreatingNew)
                        self.isCreatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            
            // --- CAMBIO 4: Dos Modificadores .sheet ---

            // Sheet 1: Para CREAR (se activa con el Bool)
            .sheet(isPresented: $isCreatingNew) {
                NavigationStack {
                    // Pasamos nil explícitamente
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: nil
                    )
                }
            }
            
            // Sheet 2: Para EDITAR (se activa cuando 'cursoToEdit' NO es nil)
            .sheet(item: $cursoToEdit) { curso in
                NavigationStack {
                    // Pasamos el curso que se clickeó
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: curso
                    )
                }
            }
            
            // Manejo de errores
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error desconocido.")
            })
        }
    }
}

#Preview {
    CursosView()
}
