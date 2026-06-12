import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("Pedido — payloads para Cloud Functions")
struct PedidoPayloadTests {

    @Test func asCloudPayloadTieneLasClavesDelContrato() {
        let pedido = TestFactory.pedido()
        let payload = pedido.asCloudPayload

        #expect(Set(payload.keys) == ["clienteId", "clienteNombre", "descripcion", "presupuesto", "tipo", "fecha"])
        #expect(payload["clienteId"] as? String == "cliente-test-id")
        #expect(payload["clienteNombre"] as? String == "Cliente Test")
        #expect(payload["presupuesto"] as? Double == 50_000)
        #expect(payload["tipo"] as? String == "Piezas")
    }

    @Test func asCloudPayloadFechaEsISO8601ConFracciones() {
        let pedido = TestFactory.pedido()
        let fechaString = pedido.asCloudPayload["fecha"] as? String
        #expect(fechaString != nil)
        // Debe ser parseable por el mismo formatter del contrato (con fracciones de segundo)
        #expect(Formatters.iso8601.date(from: fechaString ?? "") == pedido.fecha)
    }

    @Test func updatePayloadTieneLasClavesEditables() {
        let pedido = TestFactory.pedido()
        let payload = pedido.updatePayload

        #expect(Set(payload.keys) == ["cliente_nombre", "descripcion", "presupuesto", "tipo", "fecha", "estado_entrega"])
        #expect(payload["estado_entrega"] as? Bool == false)
        #expect(payload["tipo"] as? String == "Piezas")
    }

    @Test func updatePayloadNoIncluyeMontosFinancieros() {
        // Crítico: los montos los calcula la Cloud Function 'actualizarPedido'.
        // Si alguien los agrega al payload, rompe la consistencia financiera.
        let payload = TestFactory.pedido().updatePayload
        #expect(payload["monto_abonado"] == nil)
        #expect(payload["monto_adeudado"] == nil)
        #expect(payload["estado_pago"] == nil)
    }

    @Test func rawValuesDeTipoPedidoCoincidenConFirestore() {
        // Los raw values son contrato con el backend — no cambiar sin actualizar Cloud Functions.
        #expect(TipoPedido.piezas.rawValue == "Piezas")
        #expect(TipoPedido.materiales.rawValue == "Materiales")
        #expect(TipoPedido.joyeria.rawValue == "Joyeria")
        #expect(TipoPedido.otros.rawValue == "Otros")
    }
}
