# Diseño: Detalle de día en CalendarioAgendaView

**Fecha:** 2026-05-27  
**Feature:** Preview de curso al tocar un día en el calendario de agenda  
**Archivos afectados:** `CalendarioAgendaView.swift` (modificado), nuevo `DetalleDiaView.swift`

---

## Contexto

`CalendarioAgendaView` muestra 3 meses en un sheet modal. Los días con cursos se colorean con `DesignSystem.Color.accion`; los feriados, con `.alerta`. Actualmente no hay interacción al tocar un día. La app web tiene la misma vista y al clickear un día con curso muestra los datos debajo. Se busca una experiencia equivalente en iOS adaptada al espacio disponible.

**Restricción de dominio:** un día puede tener como máximo un curso (no hay superposición de cursos en el cronograma).

---

## Comportamiento

- Tocar un día **con curso** → abre `DetalleDiaView` como bottom sheet parcial.
- Tocar un día **sin curso** → sin efecto.
- Tocar el **mismo día** mientras el sheet está abierto → cierra el sheet (`itemSeleccionado = nil`).
- Swipe down en el sheet → cierra.
- El calendario **permanece interactivo** mientras el sheet está abierto (el usuario puede tocar otro día sin cerrar primero).
- El sheet es **solo lectura**: no hay acciones. Cualquier interacción profunda se realiza en la lista de agenda.

---

## Arquitectura

### Estado nuevo en `CalendarioAgendaView`

```swift
@State private var itemSeleccionado: CronogramaItem?
```

### Cadena de callbacks

```
CalendarioAgendaView
  └─ MesCalendarioView(onTapDia: (Int) -> Void)
       └─ DiaCalendarioView(onTap: (() -> Void)?)
```

- `DiaCalendarioView` recibe `onTap: (() -> Void)?`. Nil para días sin curso.
- Agrega `.contentShape(Rectangle())` + `.onTapGesture { onTap?() }` cuando `onTap != nil`.
- `MesCalendarioView` recibe `onTapDia: (Int) -> Void` y lo pasa a cada celda ocupada.
- `CalendarioAgendaView` resuelve `dia + mes + año → CronogramaItem?` buscando en `items` (O(n), n ≤ ~50).

### Resolución de item por día

```swift
private func itemParaDia(dia: Int, mes: Int, año: Int) -> CronogramaItem? {
    items.first { item in
        let comps = bsasCalendar.dateComponents([.year, .month, .day], from: item.fecha)
        return comps.year == año && comps.month == mes && comps.day == dia
    }
}
```

Toggle: si el item encontrado es el mismo que `itemSeleccionado`, se asigna `nil` (cierra). Si es distinto, se asigna el nuevo item.

### Sheet

```swift
.sheet(item: $itemSeleccionado) { item in
    DetalleDiaView(item: item)
        .presentationDetents([.fraction(0.28)])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.28)))
        .presentationDragIndicatorVisibility(.visible)
}
```

El modificador `.sheet` se adjunta al `ScrollView` dentro del `NavigationStack`, no al `NavigationStack` en sí, para evitar conflictos con el sheet padre (que es `CalendarioAgendaView` presentado como `.sheet` desde `AgendaView`).

**Requisito mínimo:** iOS 16.4 (necesario para `presentationBackgroundInteraction(.enabled(upThrough:))`). Verificar deployment target en `project.pbxproj`.

---

## Nuevo componente: `DetalleDiaView`

**Archivo:** `gestion-taller-vidrio/Views/DetalleDiaView.swift`

**Datos mostrados:**
| Campo | Fuente | Formato |
|---|---|---|
| Tipo de curso | `item.cursoTipo` | Badge con `cursoTipo.color` |
| Nombre del curso | `item.cursoNombre` | `.title3` / `.headline` |
| Fecha | `item.fecha` | "Jueves 15 de mayo 2026" (DateFormatter existente, locale `es`) |
| Inscriptos | `item.cant_inscriptos` | "N inscripto/s" o "Sin inscriptos" si nil/0 |

**`precio_curso` no se muestra** — el preview está orientado a ocupación, no a finanzas.

**Layout aproximado:**
```
┌─────────────────────────────┐
│         ▬                   │  drag indicator
│                             │
│  [Taller]                   │  badge coloreado
│  Vitrofusión                │  nombre del curso
│  Jueves 15 de mayo 2026     │  fecha, color secondary
│                             │
│  👤  3 inscriptos           │  cant_inscriptos
│                             │
└─────────────────────────────┘
```

Usa tokens de `DesignSystem` (espaciado, radio) y los formatters existentes de `Formatters.swift`.

---

## Fallback (Opción B)

Si `presentationBackgroundInteraction` no funciona correctamente en el contexto sheet-dentro-de-sheet durante implementación:

- Eliminar el `.sheet(item:)` de `DetalleDiaView`.
- Agregar `DetalleDiaView` como card animada inline dentro del `ScrollView` de `CalendarioAgendaView`, justo debajo de `leyenda`.
- Animación: `.transition(.move(edge: .top).combined(with: .opacity))` con `withAnimation(.spring(duration: 0.3))`.
- El resto del diseño (callbacks, estado, `DetalleDiaView` content) permanece idéntico.

---

## Archivos a modificar/crear

| Archivo | Cambio |
|---|---|
| `Views/CalendarioAgendaView.swift` | `@State itemSeleccionado`, callbacks, `.sheet`, `itemParaDia()` |
| `Views/DetalleDiaView.swift` | **Nuevo** — vista del mini-sheet |

Sin cambios en: `AgendaView`, `AgendaViewModel`, repositorios, `AppContainer`, modelos, ni navegación.

---

## Criterio de éxito

1. Tocar día con curso → sheet parcial aparece con datos correctos del curso.
2. El calendario sigue respondiendo a taps mientras el sheet está visible.
3. Tocar mismo día → sheet se cierra.
4. Tocar día diferente → sheet actualiza datos sin cerrar/abrir (SwiftUI lo hace automáticamente vía `item` binding).
5. Días sin curso no reaccionan al tap.
6. Sin regresiones en el resto de `AgendaView`.
