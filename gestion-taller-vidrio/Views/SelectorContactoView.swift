import SwiftUI

struct SelectorContactoView: View {
    @Environment(\.dismiss) var dismiss

    private let contactos: [Contacto]

    // Bindings
    @Binding var selectedID: String
    @Binding var selectedNombre: String

    // Estado de búsqueda
    @State private var searchText = ""

    init(contactos: [Contacto], selectedID: Binding<String>, selectedNombre: Binding<String>) {
        self.contactos = contactos.sorted {
            $0.nombreCompleto.localizedCaseInsensitiveCompare($1.nombreCompleto) == .orderedAscending
        }

        self._selectedID = selectedID
        self._selectedNombre = selectedNombre
    }

    var contactosFiltrados: [Contacto] {
        if searchText.isEmpty {
            return contactos
        } else {
            return contactos.filter {
                $0.nombreCompleto.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        List(contactosFiltrados) { contacto in
            Button {
                self.selectedID = contacto.id ?? ""
                self.selectedNombre = contacto.nombreCompleto
                dismiss()
            } label: {
                HStack {
                    Text(contacto.nombreCompleto)
                        .foregroundStyle(.primary)

                    Spacer()

                    if contacto.id == selectedID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                            .fontWeight(.bold)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar cliente...")
        .navigationTitle("Seleccionar Cliente")
        .navigationBarTitleDisplayMode(.inline)
    }
}
