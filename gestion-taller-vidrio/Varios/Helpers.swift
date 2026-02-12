import SwiftUI
import FirebaseFirestore

// MARK: - Error Alert Reutilizable
extension View {
    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        self.alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage.wrappedValue != nil },
            set: { if !$0 { errorMessage.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.wrappedValue ?? "Ocurrió un error desconocido.")
        }
    }
}


// MARK: - Vista de Fila de Pago
struct PagoRowView: View {
    let pago: Pago

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pago.fecha, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pago.medio_de_pago.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
            Text(Formatters.money(pago.monto))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Origen (Pedido o Inscripcion)
enum Origen: Identifiable {
    case pedido(Pedido)
    case inscripcion(Inscripcion)
    
    var id: String {
        switch self {
        case .pedido(let p): return p.id ?? UUID().uuidString
        case .inscripcion(let i): return i.id ?? UUID().uuidString
        }
    }

    var documentID: String? {
        switch self {
        case .pedido(let p): return p.id
        case .inscripcion(let i): return i.id
        }
    }
      
    var ref: DocumentReference? {
        guard let id = self.documentID else { return nil }
        let db = FirestoreManager.shared.db
        switch self {
        case .pedido:
            return db.collection("pedidos").document(id)
        case .inscripcion:
            return db.collection("inscripciones").document(id)
        }
    }
    
    var tipo: OrigenTipoPago {
        switch self {
        case .pedido: return .pedido
        case .inscripcion: return .inscripcion
        }
    }
      
    var clienteID: String {
        switch self {
        case .pedido(let p): return p.cliente_id
        case .inscripcion(let i): return i.alumnoId
        }
    }
      
    var clienteNombre: String {
        switch self {
        case .pedido(let p): return p.cliente_nombre
        case .inscripcion(let i): return i.alumno_nombre
        }
    }
      
    var descripcionOrigen: String {
        switch self {
        case .pedido(let p):
            return "Pago Pedido #\(p.numero_pedido)"
            
        case .inscripcion(let i):
            return "\(i.cursoNombre) (\(Formatters.dateDayMonth(i.fecha_curso)))"
        }
    }
      
    var montoAdeudado: Double {
        switch self {
        case .pedido(let p): return p.monto_adeudado
        case .inscripcion(let i): return i.monto_adeudado
        }
    }

    var tipoVenta: TipoVenta {
        switch self {
        case .pedido(let p):
            switch p.tipo {
            case .piezas: return .piezas
            case .materiales: return .materiales
            case .joyeria: return .joyeria
            case .otros: return .otros
            }
        case .inscripcion(let i):
            switch i.cursoTipo {
            case .presencial: return .presencial
            case .online: return .online
            case .taller: return .taller
            }
        }
    }
}

extension CronogramaItem {
    // Genera la URL de inscripción
    var inscripcionURL: URL? {
        guard let docID = id else { return nil }
        return URL(string: "https://taller-glass-v2.web.app/inscribir/\(docID)")
    }

    var mensajeCompartir: String {
        // Usamos formato abreviado seguro
        let fechaFormateada = fecha.formatted(date: .abbreviated, time: .shortened)
        
        return """
        ¡Hola! Te invito a inscribirte al curso de *\(cursoNombre)*.
        
        📅 Fecha: \(fechaFormateada)
        
        👇 Inscribite en el siguiente enlace:
        """
    }
}

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



