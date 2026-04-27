import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class ContactosRepository {

    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions

    private var contactosCache: [Contacto]?

    /// Obtiene todos los contactos ordenados por nombre y apellido.
    /// Usa cache en memoria; se invalida automáticamente en save/update/delete.
    func fetchContactos(forceRefresh: Bool = false) async throws -> [Contacto] {
        if !forceRefresh, let cached = contactosCache {
            return cached
        }

        let snapshot = try await db.collection("contactos")
            .order(by: "nombre", descending: false)
            .order(by: "apellido", descending: false)
            .getDocuments()

        let contactos = snapshot.documents.compactMap { document in
            document.decodeSafely(as: Contacto.self)
        }
        contactosCache = contactos
        return contactos
    }

    /// Guarda un contacto (crear o actualizar mediante setData merge).
    /// - Parameters:
    ///   - contacto: El objeto con los datos.
    ///   - uid: El ID explícito donde queremos guardar el documento.
    func saveContacto(_ contacto: Contacto, uid: String) async throws {
        let data = try Firestore.Encoder().encode(contacto)
        try await db.collection("contactos").document(uid).setData(data, merge: true)
        contactosCache = nil
    }

    /// Actualiza un contacto existente y propaga el nombre a pedidos, inscripciones y pagos.
    func updateContacto(_ contacto: Contacto, id: String) async throws {
        let payload: [String: Any] = [
            "id": id,
            "nuevosDatos": [
                "nombre": contacto.nombre,
                "apellido": contacto.apellido,
                "email": contacto.email as Any,
                "telefono": contacto.telefono as Any,
                "direccion": contacto.direccion as Any,
                "redes_sociales": contacto.redes_sociales as Any,
                "cuit": contacto.cuit as Any,
                "notas": contacto.notas as Any
            ]
        ]
        do {
            _ = try await functions.httpsCallable("actualizarContacto").call(payload)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
        contactosCache = nil
    }

    /// Borra un contacto.
    func deleteContacto(contacto: Contacto) async throws {
        guard let id = contacto.id else {
            throw URLError(.cannotRemoveFile)
        }
        try await db.collection("contactos").document(id).delete()
        contactosCache = nil
    }
}
