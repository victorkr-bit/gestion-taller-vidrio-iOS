import Foundation
import FirebaseFirestore
import FirebaseFunctions
import os

// Esta clase centraliza la conexión a Firebase y el manejo de errores.
// Reemplaza la configuración interna que tenía la God Class.
final class FirestoreManager {
    
    // Singleton para acceso global
    static let shared = FirestoreManager()
    
    // Instancias únicas de Firebase
    let db: Firestore
    lazy var functions: Functions = Functions.functions(region: "southamerica-east1")
    
    private init() {
        self.db = Firestore.firestore()
        // Aquí podrías agregar configuraciones de caché si hiciera falta en el futuro
    }
    
    // Lógica extraída de FirestoreTallerRepository [cite: 169]
    func mapCloudError(_ error: Error) -> TallerError {
        // 1. Casteamos a NSError para acceder al código y dominio
        let nsError = error as NSError
        
        // 2. Verificamos si es un error de Functions
        if nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code)
            let message = nsError.localizedDescription
            
            switch code {
            case .failedPrecondition:
              // Backend dice: "No se puede borrar: Tiene pagos asociados..." [cite: 171]
                if message.lowercased().contains("pagos") {
                    return .tienePagos
                }
               // Backend dice: "No se puede borrar el curso: Tiene alumnos inscriptos." [cite: 172]
                if message.lowercased().contains("inscriptos") || message.lowercased().contains("alumnos") {
                    return .tieneInscriptos
                }
                return .transaccionFallida(message)
                
            case .notFound:
               return .origenNoEncontrado // [cite: 173]
                
            case .unauthenticated:
                return .transaccionFallida("Sesión no válida. Por favor, vuelve a iniciar sesión.")
                
            default:
                return .transaccionFallida(message) // [cite: 174]
            }
        }
        
        // 3. Si no es un error de Functions (ej. sin internet), lo pasamos tal cual
        return .transaccionFallida(error.localizedDescription) // [cite: 175]
    }

    /// Devuelve un mensaje amigable en español para errores de red/conexión.
    /// Si no es un error de red, retorna `error.localizedDescription` tal cual.
    static func mensajeAmigable(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "Sin conexión a internet. Verificá tu conexión e intentá de nuevo."
            case NSURLErrorTimedOut:
                return "La operación tardó demasiado. Intentá de nuevo en unos momentos."
            case NSURLErrorNetworkConnectionLost:
                return "Se perdió la conexión. Verificá tu conexión e intentá de nuevo."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "No se pudo conectar al servidor. Intentá de nuevo más tarde."
            default:
                return "Error de conexión. Verificá tu conexión e intentá de nuevo."
            }

        case "FIRFirestoreErrorDomain":
            switch nsError.code {
            case 14: // unavailable
                return "El servidor no está disponible en este momento. Intentá más tarde."
            case 4:  // deadline exceeded
                return "La operación tardó demasiado. Intentá de nuevo en unos momentos."
            default:
                return error.localizedDescription
            }

        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Decodificación segura con logging

private let firestoreLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "taller-cris", category: "Firestore")

extension QueryDocumentSnapshot {
    /// Decodifica el documento al tipo indicado. Si falla, loguea el error y retorna nil.
    func decodeSafely<T: Decodable>(as type: T.Type) -> T? {
        do {
            return try data(as: type)
        } catch let decodingError as DecodingError {
            let detail: String
            switch decodingError {
            case .keyNotFound(let key, _):
                detail = "campo faltante: '\(key.stringValue)'"
            case .typeMismatch(_, let ctx):
                detail = "tipo incorrecto en '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))': \(ctx.debugDescription)"
            case .valueNotFound(_, let ctx):
                detail = "valor nulo en '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'"
            case .dataCorrupted(let ctx):
                detail = "datos corruptos en '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))': \(ctx.debugDescription)"
            @unknown default:
                detail = decodingError.localizedDescription
            }
            firestoreLogger.warning("Error decodificando \(String(describing: type)) [doc: \(self.documentID)]: \(detail)")
            return nil
        } catch {
            firestoreLogger.warning("Error decodificando \(String(describing: type)) [doc: \(self.documentID)]: \(error.localizedDescription)")
            return nil
        }
    }
}
