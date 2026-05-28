# Calendario Detalle de Día — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Al tocar un día con curso en el calendario modal, mostrar un bottom sheet parcial con nombre, tipo, fecha e inscriptos del curso — sin salir del calendario.

**Architecture:** Cadena de callbacks `CalendarioAgendaView → MesCalendarioView → DiaCalendarioView`. Estado `@State private var itemSeleccionado: CronogramaItem?` controla el sheet. Sheet se presenta con `presentationDetents([.fraction(0.28)])` y `presentationBackgroundInteraction(.enabled)` adjunto al `ScrollView` dentro del `NavigationStack`.

**Tech Stack:** SwiftUI, iOS 26.1 (deployment target confirma soporte total de `presentationBackgroundInteraction`). Sin cambios en Firebase, repositorios, ni navegación.

**Notas de dominio:**
- Un día tiene como máximo un curso.
- El preview es solo lectura.
- `CronogramaItem` ya es `Identifiable` con `@DocumentID var id: String?`.
- No hay test targets en el proyecto — build exitoso + smoke test manual en simulador verifican correctitud.

---

## File Map

| Archivo | Acción |
|---|---|
| `gestion-taller-vidrio/Views/DetalleDiaView.swift` | **Crear** — vista del mini-sheet |
| `gestion-taller-vidrio/Views/CalendarioAgendaView.swift` | **Modificar** — `DiaCalendarioView` + `MesCalendarioView` + `CalendarioAgendaView` |

---

## Task 1: Crear `DetalleDiaView`

**Files:**
- Create: `gestion-taller-vidrio/Views/DetalleDiaView.swift`

- [ ] **Step 1.1: Crear el archivo con el contenido completo**

```swift
import SwiftUI

struct DetalleDiaView: View {
    let item: CronogramaItem

    private static let fechaFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es")
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        fmt.dateFormat = "EEEE d 'de' MMMM yyyy"
        return fmt
    }()

    private var fechaFormateada: String {
        Self.fechaFormatter.string(from: item.fecha).capitalized
    }

    private var inscriptosTexto: String {
        let n = item.cant_inscriptos ?? 0
        if n == 0 { return "Sin inscriptos" }
        return "\(n) \(n == 1 ? "inscripto" : "inscriptos")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text(item.cursoTipo.descripcion)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(item.cursoTipo.color)
                .padding(.horizontal, DesignSystem.Espaciado.s)
                .padding(.vertical, 4)
                .background(item.cursoTipo.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.etiqueta))

            Text(item.cursoNombre)
                .font(.title3)
                .fontWeight(.semibold)

            Text(fechaFormateada)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(inscriptosTexto, systemImage: "person.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Espaciado.l)
    }
}
```

- [ ] **Step 1.2: Build para verificar que compila**

```bash
xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build \
  2>&1 | grep -E "error:|BUILD"
```

Esperado: `BUILD SUCCEEDED` sin errores.

- [ ] **Step 1.3: Commit**

```bash
git add gestion-taller-vidrio/Views/DetalleDiaView.swift
git commit -m "feat(calendario): agregar DetalleDiaView para preview de curso"
```

---

## Task 2: Agregar tap a `DiaCalendarioView` y `MesCalendarioView`

**Files:**
- Modify: `gestion-taller-vidrio/Views/CalendarioAgendaView.swift`

- [ ] **Step 2.1: Reemplazar `DiaCalendarioView` completo (líneas 152–193)**

```swift
struct DiaCalendarioView: View {
    let dia: Int
    let ocupado: Bool
    let feriado: Bool
    var onTap: (() -> Void)? = nil

    private var fondoColor: SwiftUI.Color {
        if ocupado { return DesignSystem.Color.accion.opacity(0.12) }
        if feriado { return DesignSystem.Color.alerta.opacity(0.12) }
        return .clear
    }

    private var textoColor: SwiftUI.Color {
        if ocupado { return DesignSystem.Color.accion }
        if feriado { return DesignSystem.Color.alerta }
        return .primary
    }

    private var puntoColor: SwiftUI.Color {
        if feriado { return DesignSystem.Color.alerta }
        if ocupado { return DesignSystem.Color.accion }
        return .clear
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dia)")
                .font(.callout)
                .fontWeight((ocupado || feriado) ? .semibold : .regular)
                .foregroundStyle(textoColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(fondoColor))

            Circle()
                .fill(puntoColor)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
```

- [ ] **Step 2.2: Reemplazar `MesCalendarioView` completo (líneas 73–150)**

```swift
struct MesCalendarioView: View {
    let mesDate: Date
    let diasOcupados: Set<DateComponents>
    let feriados: Set<DateComponents>
    var onTapDia: ((Int) -> Void)? = nil

    private let diasSemana = ["L", "M", "X", "J", "V", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var diasEnMes: Int {
        bsasCalendar.range(of: .day, in: .month, for: mesDate)!.count
    }

    private var primerDiaSemana: Int {
        let weekday = bsasCalendar.component(.weekday, from: mesDate)
        return (weekday - 2 + 7) % 7
    }

    private var nombreMes: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_AR")
        fmt.dateFormat = "MMMM yyyy"
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        return fmt.string(from: mesDate).capitalized
    }

    private var año: Int { bsasCalendar.component(.year, from: mesDate) }
    private var mes: Int { bsasCalendar.component(.month, from: mesDate) }

    private var celdas: [Int?] {
        Array(repeating: nil, count: primerDiaSemana) + (1...diasEnMes).map { Optional($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text(nombreMes)
                .font(.headline)

            HStack(spacing: 0) {
                ForEach(diasSemana, id: \.self) { dia in
                    Text(dia)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: DesignSystem.Espaciado.xs) {
                ForEach(Array(celdas.enumerated()), id: \.offset) { _, dia in
                    if let dia {
                        DiaCalendarioView(
                            dia: dia,
                            ocupado: estaOcupado(dia: dia),
                            feriado: esFeriado(dia: dia),
                            onTap: estaOcupado(dia: dia) ? { onTapDia?(dia) } : nil
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(DesignSystem.Espaciado.l)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
    }

    private func comps(dia: Int) -> DateComponents {
        var c = DateComponents()
        c.year = año
        c.month = mes
        c.day = dia
        return c
    }

    private func estaOcupado(dia: Int) -> Bool { diasOcupados.contains(comps(dia: dia)) }
    private func esFeriado(dia: Int) -> Bool { feriados.contains(comps(dia: dia)) }
}
```

- [ ] **Step 2.3: Build para verificar**

```bash
xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build \
  2>&1 | grep -E "error:|BUILD"
```

Esperado: `BUILD SUCCEEDED` sin errores.

- [ ] **Step 2.4: Commit**

```bash
git add gestion-taller-vidrio/Views/CalendarioAgendaView.swift
git commit -m "feat(calendario): agregar callbacks de tap en DiaCalendarioView y MesCalendarioView"
```

---

## Task 3: Conectar estado y sheet en `CalendarioAgendaView`

**Files:**
- Modify: `gestion-taller-vidrio/Views/CalendarioAgendaView.swift`

- [ ] **Step 3.1: Reemplazar `CalendarioAgendaView` completo (líneas 10–71)**

```swift
struct CalendarioAgendaView: View {
    let items: [CronogramaItem]
    let feriados: Set<DateComponents>
    @Environment(\.dismiss) private var dismiss
    @State private var itemSeleccionado: CronogramaItem?

    private var diasOcupados: Set<DateComponents> {
        Set(items.map { item in
            let raw = bsasCalendar.dateComponents([.year, .month, .day], from: item.fecha)
            var comps = DateComponents()
            comps.year = raw.year
            comps.month = raw.month
            comps.day = raw.day
            return comps
        })
    }

    private var meses: [Date] {
        let ahora = Date()
        let inicioMes = bsasCalendar.date(from: bsasCalendar.dateComponents([.year, .month], from: ahora))!
        return [
            inicioMes,
            bsasCalendar.date(byAdding: .month, value: 1, to: inicioMes)!,
            bsasCalendar.date(byAdding: .month, value: 2, to: inicioMes)!
        ]
    }

    private func itemParaDia(dia: Int, mes: Int, año: Int) -> CronogramaItem? {
        items.first { item in
            let comps = bsasCalendar.dateComponents([.year, .month, .day], from: item.fecha)
            return comps.year == año && comps.month == mes && comps.day == dia
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Espaciado.xl) {
                    leyenda
                    ForEach(meses, id: \.self) { mes in
                        MesCalendarioView(
                            mesDate: mes,
                            diasOcupados: diasOcupados,
                            feriados: feriados,
                            onTapDia: { dia in
                                let año = bsasCalendar.component(.year, from: mes)
                                let mesNum = bsasCalendar.component(.month, from: mes)
                                if let encontrado = itemParaDia(dia: dia, mes: mesNum, año: año) {
                                    itemSeleccionado = encontrado.id == itemSeleccionado?.id ? nil : encontrado
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Espaciado.l)
                .padding(.vertical, DesignSystem.Espaciado.m)
                .sheet(item: $itemSeleccionado) { item in
                    DetalleDiaView(item: item)
                        .presentationDetents([.fraction(0.28)])
                        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.28)))
                        .presentationDragIndicatorVisibility(.visible)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var leyenda: some View {
        HStack(spacing: DesignSystem.Espaciado.xl) {
            Label("Con cursos", systemImage: "circle.fill")
                .foregroundStyle(DesignSystem.Color.accion)
            Label("Feriado", systemImage: "circle.fill")
                .foregroundStyle(DesignSystem.Color.alerta)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3.2: Build final**

```bash
xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build \
  2>&1 | grep -E "error:|BUILD"
```

Esperado: `BUILD SUCCEEDED` sin errores.

- [ ] **Step 3.3: Smoke test manual en simulador**

Abrir la app en iPhone 17 Pro simulator → tab Agenda → botón Calendario (toolbar):

1. Tocar un día **sin curso** → nada pasa.
2. Tocar un día **con curso** → aparece bottom sheet con badge de tipo (coloreado), nombre del curso, fecha larga ("Jueves X de mes año") e inscriptos.
3. Con el sheet abierto, tocar otro día con curso → sheet actualiza datos sin cerrar/abrir.
4. Tocar el mismo día que ya está abierto → sheet se cierra.
5. Swipe down en el sheet → se cierra.
6. El calendario sigue siendo interactivo mientras el sheet está visible.
7. Botón "Listo" sigue cerrando el modal completo.

- [ ] **Step 3.4: Commit final**

```bash
git add gestion-taller-vidrio/Views/CalendarioAgendaView.swift
git commit -m "feat(calendario): detalle de día al tocar en el calendario de agenda"
```

---

## Fallback si `presentationBackgroundInteraction` falla

Si en el smoke test el calendario queda bloqueado cuando el sheet está abierto, aplicar:

1. Remover el `.sheet(item: $itemSeleccionado)` del `ScrollView`.
2. Insertar en el `VStack`, entre `leyenda` y el `ForEach`:

```swift
if let item = itemSeleccionado {
    DetalleDiaView(item: item)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

3. Envolver las asignaciones de `itemSeleccionado` en `withAnimation(.spring(duration: 0.3)) { ... }`.

`DetalleDiaView` no cambia — solo cambia el punto de presentación.
