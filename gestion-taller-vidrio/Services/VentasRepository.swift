import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class VentasRepository {

    // Acceso a la infraestructura compartida
    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions

    // Cache de contactos (compartido entre VMs)
    private var contactosCache: [Contacto]?

    // MARK: - Contactos (Clientes)

    /// Obtiene todos los contactos ordenados por nombre y apellido.
    /// Usa cache en memoria; se invalida automáticamente en save/delete.
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
    
    /// Guarda un contacto (Crear o Actualizar).
    /// - Parameters:
    ///   - contacto: El objeto con los datos.
    ///   - uid: El ID explícito donde queremos guardar el documento.
    func saveContacto(_ contacto: Contacto, uid: String) async throws {
        let data = try Firestore.Encoder().encode(contacto)
        try await db.collection("contactos").document(uid).setData(data, merge: true)
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
    
    // MARK: - Pedidos
    
    /// Obtiene los pedidos más recientes.
    func fetchPedidos(limit: Int = 50) async throws -> [Pedido] {
        let snapshot = try await db.collection("pedidos")
            .order(by: "fecha", descending: true) // Los más nuevos primero
            .limit(to: limit)
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            document.decodeSafely(as: Pedido.self)
        }
    }
    
    /// Escucha cambios en tiempo real en la lista de pedidos.
    func listenToPedidos(completion: @escaping (Result<[Pedido], Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("pedidos")
            .order(by: "fecha", descending: true)
            
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let pedidos = documents.compactMap { $0.decodeSafely(as: Pedido.self) }
            completion(.success(pedidos))
        }
    }
    
    /// Guarda un pedido (decide si es creación o actualización).
    func savePedido(pedido: Pedido, existingID: String? = nil) async throws {
        if let id = existingID {
            // A. EDICIÓN
            try await updatePedidoRemote(pedido, id: id)
        } else {
            // B. CREACIÓN
            try await createPedidoRemote(pedido)
        }
    }
    
    /// Borra un pedido mediante Cloud Function (valida si tiene pagos).
    func deletePedido(pedido: Pedido) async throws {
        guard let id = pedido.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "pedidos",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            // Usamos el helper del Manager para mapear el error
            throw FirestoreManager.shared.mapCloudError(error)
        }
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

    // MARK: - Helpers Privados (Cloud Functions)

    private func createPedidoRemote(_ pedido: Pedido) async throws {
         let data = pedido.asCloudPayload
         _ = try await functions.httpsCallable("crearPedido").call(data)
    }

    private func updatePedidoRemote(_ pedido: Pedido, id: String) async throws {
        let payload: [String: Any] = [
            "id": id,
            "nuevosDatos": pedido.updatePayload
        ]
        
        do {
            _ = try await functions.httpsCallable("actualizarPedido").call(payload)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
}
