# GEMINI.md - Taller Cris (iOS)

## Proyecto: Gestión de Taller de Vidrio Artístico
"Taller Cris" es una aplicación de gestión para un taller de arte en vidrio, diseñada para iPad/iPhone. Centraliza el manejo de pedidos, pagos, programación de cursos, inscripciones, contactos y tableros financieros.

## Tecnologías Principales
- **Lenguaje:** Swift 6.0 (SwiftUI)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions)
- **Arquitectura:** MVVM + Repository Pattern
- **Inyección de Dependencias:** `AppContainer` (Singleton @MainActor)
- **Navegación:** `NavigationManager` (EnvironmentObject con `NavigationPath`)
- **Gestión de Datos:** Firestore para lectura en tiempo real, Cloud Functions para escrituras consistentes.

## Estructura del Código
- `gestion-taller-vidrio/`: Directorio raíz de la fuente.
  - `Modelos/`: Entidades de dominio (`Pedido`, `Inscripcion`, `Pago`, `Curso`, `Contacto`, etc.). Incluyen métodos `asCloudPayload` para Firebase.
  - `ViewModels/`: Lógica de vista (10 ViewModels principales). Todos usan `@MainActor` y `ObservableObject`.
  - `Views/`: Componentes de interfaz en SwiftUI.
  - `Services/`: 
    - `AppContainer`: Punto central de ensamblaje (DI).
    - `FirestoreManager`: Singleton para configuración de Firebase y mapeo de errores.
    - `Repositories`: `FinanzasRepository`, `TallerRepository`, `VentasRepository`.
  - `Varios/`: 
    - `AppEnums.swift`: Definición de enums compartidos (`TipoCurso`, `EstadoInscripcion`, `TipoVenta`, etc.) con decodificación resiliente.
    - `Formatters.swift`: Formateadores de moneda (`es_AR`) y fechas (Argentina).
    - `NavigationManager.swift`: Control de pestañas y rutas de navegación.
    - `Helpers.swift`: Utilidades de UI y lógica auxiliar.

## Convenciones y Estándares
- **Idioma:** Los comentarios, nombres de variables, valores de enums y texto de la interfaz están en **Español**.
- **Consistencia de Datos:** Las escrituras **deben** realizarse a través de Cloud Functions para asegurar la denormalización (ej: nombres de clientes en pedidos/pagos).
- **Manejo de Errores:** Usar `TallerError` para errores de dominio. `FirestoreManager.shared.mapCloudError()` centraliza el mapeo de errores de Firebase.
- **UI/UX:** Se prefiere el uso de `CardView` y `GenericRowView` para mantener la estética consistente.
- **Firebase Functions:** Región configurada en `southamerica-east1`.

## Comandos de Desarrollo
- **Build (CLI):** 
  ```bash
  xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- **Dependencias:** Gestionadas exclusivamente por Swift Package Manager (SPM).
- **Tests:** Actualmente no existen targets de prueba configurados.

## Flujo de Trabajo
1. **Investigación:** Analizar el `AppContainer` para entender qué repositorios e inyecciones necesita un ViewModel.
2. **Estrategia:** Siempre verificar si una operación de escritura requiere una Cloud Function antes de intentar escribir directamente en Firestore.
3. **Ejecución:** Mantener las propiedades de los modelos sincronizadas con los payloads esperados por el backend.
4. **Validación:** El simulador preferido para pruebas es **iPhone 17 Pro**.


