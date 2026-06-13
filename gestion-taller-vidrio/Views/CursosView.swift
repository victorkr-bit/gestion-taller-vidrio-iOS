import SwiftUI

struct CursosView: View {

    @StateObject private var viewModel: CursosViewModel

    init(tallerRepo: any TallerRepositorio) {
        _viewModel = StateObject(wrappedValue: CursosViewModel(repository: tallerRepo))
    }
    
    @State private var cursoToEdit: Curso?
    @State private var isCreatingNew = false
    @State private var cursoToDelete: Curso?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.cursos.isEmpty {
                    ProgressView("Cargando cursos...")
                } else {
                    List {
                        ForEach(viewModel.cursos) { curso in
                            Button {
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
                                                .foregroundStyle(curso.tipo.color)
                                                .padding(4)
                                                .background(curso.tipo.color.opacity(0.15))
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
                        .onDelete { offsets in
                        if let index = offsets.first {
                            cursoToDelete = viewModel.cursos[index]
                        }
                    }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.startListening()
                    }
                }
            }
            .navigationTitle("Catálogo de Cursos")
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
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: nil
                    )
                }
            }
            
            .sheet(item: $cursoToEdit) { curso in
                NavigationStack {
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: curso
                    )
                }
            }
            
            .errorAlert($viewModel.errorMessage)
            .alert("Eliminar Curso", isPresented: Binding<Bool>(
                get: { cursoToDelete != nil },
                set: { if !$0 { cursoToDelete = nil } }
            )) {
                Button("Eliminar", role: .destructive) {
                    if let curso = cursoToDelete, let index = viewModel.cursos.firstIndex(where: { $0.id == curso.id }) {
                        viewModel.deleteCurso(at: IndexSet(integer: index))
                    }
                    cursoToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    cursoToDelete = nil
                }
            } message: {
                Text("¿Eliminar \"\(cursoToDelete?.nombre ?? "")\"? Esta acción no se puede deshacer.")
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CursosView(tallerRepo: PreviewContainer.shared.tallerRepo)
    }
    .environmentObject(NavigationManager())
}
#endif
