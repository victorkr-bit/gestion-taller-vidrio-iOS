import SwiftUI
import FirebaseFirestore


// --- Vista de Fila de Pago ---
// (Extraída de CronogramaDetailView para ser usada también en CajaView)
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

// --- Helper para Tarea 4.1 ---
// Este enum nos permite pasar de forma segura el Pedido o la Inscripcion
// a la función registrarPago() del repositorio.
enum Origen: Identifiable {
    case pedido(Pedido)
    case inscripcion(Inscripcion)
    
    // 2. Esta es la nueva propiedad 'id' (NO opcional)
    //    Requerida por Identifiable y usada por el .sheet()
    var id: String {
        switch self {
        case .pedido(let p): return p.id ?? UUID().uuidString
        case .inscripcion(let i): return i.id ?? UUID().uuidString
        }
    }

    // 3. Renombramos la 'id' original (opcional) a 'documentID'
    var documentID: String? {
        switch self {
        case .pedido(let p): return p.id
        case .inscripcion(let i): return i.id
        }
    }
      
    var ref: DocumentReference? {
        // 4. Actualizamos 'ref' para que use 'documentID'
        //    Esto soluciona el error: "must have Optional type"
        guard let id = self.documentID else { return nil }
         
        switch self {
        case .pedido:
            return Firestore.firestore().collection("pedidos").document(id)
        case .inscripcion:
            return Firestore.firestore().collection("inscripciones").document(id)
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
      
    // --- AQUÍ ESTÁ EL CAMBIO SOLICITADO ---
    var descripcionOrigen: String {
        switch self {
        case .pedido(let p):
            return "Pago Pedido #\(p.numero_pedido)"
            
        case .inscripcion(let i):
            // Creamos el formateador para obtener día/mes
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_AR")
            formatter.dateFormat = "dd/MM" // Ejemplo: 12/10
            
            let fechaTexto = formatter.string(from: i.fecha_curso)
            
            // Retornamos el formato: "Nombre del Curso (Fecha)"
            return "\(i.cursoNombre) (\(fechaTexto))"
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

    // Genera el mensaje para WhatsApp
    // CAMBIO: Ya no interpolamos la URL aquí adentro.
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
    
    // Almacenamos la lista YA ordenada para no reordenar en cada render
    private let contactos: [Contacto]
    
    // Bindings
    @Binding var selectedID: String
    @Binding var selectedNombre: String
    
    // Estado de búsqueda
    @State private var searchText = ""
    
    // MARK: - Init Optimizado
    init(contactos: [Contacto], selectedID: Binding<String>, selectedNombre: Binding<String>) {
        // 1. OPTIMIZACIÓN: Ordenamos la lista UNA sola vez al inyectarla.
        // Esto evita que la app ordene cientos de contactos cada vez que la vista se redibuja.
        self.contactos = contactos.sorted {
            $0.nombreCompleto.localizedCaseInsensitiveCompare($1.nombreCompleto) == .orderedAscending
        }
        
        // Inicializamos los bindings
        self._selectedID = selectedID
        self._selectedNombre = selectedNombre
    }
    
    // MARK: - Lógica de Filtrado Ligera
    var contactosFiltrados: [Contacto] {
        if searchText.isEmpty {
            // Retornamos la lista que ya ordenamos en el init
            return contactos
        } else {
            // El filtro respeta el orden original.
            // Como 'contactos' ya está ordenado alfabéticamente, el resultado filtrado también lo estará.
            // No hace falta volver a llamar a .sorted().
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



