import Foundation

struct SearchEngine {
    /// Filtra una colección basándose en términos normalizados (ignora tildes y mayúsculas).
    /// Implementa lógica "AND": el ítem debe contener todas las palabras de la búsqueda.
    static func filtrar<T>(items: [T], query: String, keyPath: (T) -> String) -> [T] {
        guard !query.isEmpty else { return items }
        
        let terminos = query
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        
        return items.filter { item in
            let contenidoBuscable = keyPath(item)
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            return terminos.allSatisfy { termino in
                contenidoBuscable.contains(termino)
            }
        }
    }
}
