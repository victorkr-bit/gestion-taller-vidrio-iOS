import Foundation

/// Matching de contactos en el cliente, espejo del que hace el backend
/// (`functions/src/contactos.ts` en el repo web) para previsualizar a qué contacto
/// se va a asociar una preinscripción antes de confirmarla. Prioridad: email > teléfono > nombre+apellido.
enum ContactoMatching {

    /// Sin tildes, minúsculas, espacios colapsados.
    static func normalizarTexto(_ texto: String) -> String {
        texto
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func normalizarEmail(_ email: String?) -> String? {
        guard let email else { return nil }
        let normalizado = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizado.isEmpty ? nil : normalizado
    }

    static func normalizarTelefono(_ telefono: String?) -> String? {
        guard let telefono else { return nil }
        let soloDigitos = telefono.filter(\.isNumber)
        return soloDigitos.isEmpty ? nil : soloDigitos
    }

    /// Busca el contacto que matchearía en el backend para estos datos tipeados.
    static func encontrarMatch(nombre: String, apellido: String, email: String?, telefono: String?, en contactos: [Contacto]) -> Contacto? {
        if let emailNorm = normalizarEmail(email),
           let match = contactos.first(where: { normalizarEmail($0.email) == emailNorm }) {
            return match
        }
        if let telefonoNorm = normalizarTelefono(telefono),
           let match = contactos.first(where: { normalizarTelefono($0.telefono) == telefonoNorm }) {
            return match
        }
        let nombreNorm = normalizarTexto(nombre)
        let apellidoNorm = normalizarTexto(apellido)
        return contactos.first {
            normalizarTexto($0.nombre) == nombreNorm && normalizarTexto($0.apellido) == apellidoNorm
        }
    }
}
