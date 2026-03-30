---
name: Áreas frágiles del proyecto
description: Zonas del código que han mostrado bugs o inconsistencias recurrentes
type: project
---

## saveVentaDirecta vs registrarPago — payload inconsistente

`FinanzasRepository.saveVentaDirecta` y `FinanzasRepository.registrarPago` llaman ambos a la misma Cloud Function `registrarPago`, pero construyen el payload de forma diferente:

- `registrarPago` incluye `"descripcion"` (campo requerido), `saveVentaDirecta` no lo incluye.
- `VentaDirectaFormView` envía `cliente_id: "default"` cuando no hay contacto seleccionado, en lugar de `""`. El valor `"default"` puede causar que el backend intente resolver un documento inexistente.

**Why:** Bug descubierto al investigar error `TallerError.transaccionFallida("INTERNAL")` en flujo de venta directa (sesión 2026-03-24).

**How to apply:** Al revisar cualquier llamada a `registrarPago`, verificar que el payload incluya `"descripcion"` y que `cliente_id` sea `""` (no `"default"`) cuando no hay contacto.

## OrigenTipoPago.ventaDirecta raw value

`OrigenTipoPago.ventaDirecta` tiene rawValue `"Venta Directa"` (con mayúsculas y espacio). El payload de `saveVentaDirecta` envía `"origenTipo": "Venta Directa"` directamente como string literal — inconsistente con el uso de `.rawValue` en otros lugares. Si el backend cambia la validación de ese campo, este hardcode fallará silenciosamente.
