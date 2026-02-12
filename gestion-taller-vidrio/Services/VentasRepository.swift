import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class VentasRepository {
    
    // Acceso a la infraestructura compartida
    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions
    
    // MARK: - Contactos (Clientes)
    
    /// Obtiene todos los contactos ordenados por nombre y apellido.
    func fetchContactos() async throws -> [Contacto] {
        // OPTIMIZACIÓN: Orden compuesto en el servidor.
        let snapshot = try await db.collection("contactos")
            .order(by: "nombre", descending: false)
            .order(by: "apellido", descending: false)
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            document.decodeSafely(as: Contacto.self)
        }
    }
    
    /// Guarda un contacto (Crear o Actualizar).
    /// - Parameters:
    ///   - contacto: El objeto con los datos.
    ///   - uid: El ID explícito donde queremos guardar el documento.
    func saveContacto(_ contacto: Contacto, uid: String) async throws {
        // 1. Codificamos el objeto
        let data = try Firestore.Encoder().encode(contacto)

        // 2. Guardamos usando el ID explícito en la ruta
        try await db.collection("contactos").document(uid).setData(data, merge: true)
    }
    
    /// Borra un contacto.
    func deleteContacto(contacto: Contacto) async throws {
        guard let id = contacto.id else {
            throw URLError(.cannotRemoveFile)
        }
        try await db.collection("contactos").document(id).delete()
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
