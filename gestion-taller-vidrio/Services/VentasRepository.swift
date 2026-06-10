import Foundation
import FirebaseFirestore
@preconcurrency import FirebaseFunctions

@MainActor
final class VentasRepository {

    // Acceso a la infraestructura compartida
    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions

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
         _ = try await functions.httpsCallable("crearPedido").call(pedido.asCloudPayload)
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
