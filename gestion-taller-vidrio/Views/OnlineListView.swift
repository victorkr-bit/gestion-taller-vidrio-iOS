import SwiftUI

struct OnlineListView: View {
    @ObservedObject var catalogoOnlineVM: CatalogoOnlineViewModel
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    var body: some View {
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

#if DEBUG
#Preview {
    let c = PreviewContainer.shared
    NavigationStack {
        OnlineListView(catalogoOnlineVM: c.catalogoOnlineVM, inscripcionesVM: c.inscripcionesVM)
    }
    .environmentObject(NavigationManager())
}
#endif
