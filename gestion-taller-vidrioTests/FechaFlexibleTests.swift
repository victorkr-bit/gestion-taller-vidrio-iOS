import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("FechaFlexible — decode tolerante")
struct FechaFlexibleTests {

    /// Contenedor mínimo para decodificar el wrapper como lo hace Inscripcion.
    private struct Caja: Codable {
        let f: FechaFlexible?
    }

    private func decodificar(_ json: String) throws -> Caja {
        try JSONDecoder().decode(Caja.self, from: Data(json.utf8))
    }

    @Test func decodeDesdeStringISO8601() throws {
        let caja = try decodificar(#"{"f": "2026-06-12T15:30:00.000Z"}"#)
        let esperada = Formatters.iso8601.date(from: "2026-06-12T15:30:00.000Z")
        #expect(caja.f?.value == esperada)
    }

    @Test func decodeDesdeDateDelDecoder() throws {
        // Rama `decode(Date.self)`: es la misma que toma un Timestamp de Firestore,
        // donde el decoder entrega la fecha ya convertida. JSONDecoder (.deferredToDate)
        // decodifica el número como segundos desde la época de referencia.
        let caja = try decodificar(#"{"f": 0}"#)
        #expect(caja.f?.value == Date(timeIntervalSinceReferenceDate: 0))
    }

    @Test func ausenciaNoLanzaError() throws {
        let caja = try decodificar("{}")
        #expect(caja.f == nil)
    }

    @Test func stringInvalidoNoLanzaErrorYQuedaNil() throws {
        // Clave del diseño: un valor basura no debe descartar el documento completo.
        let caja = try decodificar(#"{"f": "no-es-una-fecha"}"#)
        #expect(caja.f != nil)
        #expect(caja.f?.value == nil)
    }

    @Test func idaYVueltaPreservaLaFecha() throws {
        let original = try decodificar(#"{"f": "2026-06-12T15:30:00.000Z"}"#)
        let data = try JSONEncoder().encode(original)
        let recodificada = try JSONDecoder().decode(Caja.self, from: data)
        #expect(recodificada.f?.value == original.f?.value)
    }
}
