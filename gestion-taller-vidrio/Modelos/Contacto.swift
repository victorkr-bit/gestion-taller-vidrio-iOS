import Foundation
import FirebaseFirestore

// Modelo para la coleccion "contactos"
struct Contacto: Codable, Identifiable {
    @DocumentID var id: String?
    var nombre: String
    var apellido: String
    
    // Opcionales según lo definido
    var email: String?
    var telefono: String?
    var direccion: String?
    var redes_sociales: String? // [cite: 162]
    var cuit: String?
    var notas: String?
    
    // Propiedad computada para vistas (ej. Listas)
    var nombreCompleto: String {
        "\(nombre) \(apellido)"
    }
}
