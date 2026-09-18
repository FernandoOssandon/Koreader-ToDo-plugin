## Why

KOReader no ofrece ninguna forma de anotar tareas pendientes. Quien lee en un e-reader y quiere registrar algo accionable —revisar una cita, buscar una referencia, comparar una traducción— tiene que salir del dispositivo y apuntarlo en otro sitio, lo que rompe la lectura y pierde el contexto del libro y la página. Un plugin nativo permite capturar la tarea sin abandonar el lector y recuperar después el punto exacto del texto que la originó.

## What Changes

- Nuevo plugin autocontenido `todolist.koplugin`, instalable copiando una carpeta al directorio de plugins, sin tocar el núcleo de KOReader.
- Alta, consulta, edición, completado y borrado de tareas, con título, notas, prioridad y fecha límite opcional.
- Almacenamiento propio en un único archivo `LuaSettings` con esquema versionado, volcado inmediato tras cada mutación y carga defensiva ante archivos ausentes o corruptos.
- Pantalla de lista en pantalla completa sobre el widget `Menu`, con filtros (todas, pendientes, hechas, vencidas, de este libro) y criterios de ordenación persistentes.
- Vínculo opcional de una tarea a un libro y una página, con salto de vuelta al documento.
- Entrada en el menú principal bajo *Herramientas → Más herramientas*, tres acciones asignables a gestos y un botón en el diálogo de selección de texto del lector.
- Sin cambios que rompan nada: el plugin es aditivo y desactivable desde *Ajustes → Plugins*.

## Capabilities

### New Capabilities

- `todo-list/task-management`: ciclo de vida de una tarea —creación, edición de sus campos, alternancia entre pendiente y hecha, y eliminación— junto con las reglas de validación e invariantes del modelo.
- `todo-list/task-storage`: persistencia de las tareas entre sesiones, formato y versionado del archivo de datos, migraciones de esquema y comportamiento ante datos ausentes, corruptos o de una versión más nueva.
- `todo-list/task-browsing`: presentación de la lista, filtrado, ordenación, recuento de pendientes y preservación del estado de navegación del usuario.
- `todo-list/koreader-integration`: puntos de contacto con el anfitrión —entrada de menú, acciones del dispatcher para gestos, botón en el diálogo de selección de texto y vínculo bidireccional entre tarea y posición en un libro.

### Modified Capabilities

Ninguna. El proyecto no tiene especificaciones previas y el plugin no altera el comportamiento de ningún componente existente de KOReader.

## Impact

- **Código nuevo**: `todolist.koplugin/` con `_meta.lua`, `main.lua`, `todostore.lua`, `todolistview.lua`, `todoeditdialog.lua` y `README.md`.
- **APIs de KOReader consumidas**: `WidgetContainer`, `Dispatcher`, `LuaSettings`, `DataStorage`, `UIManager`, `ui/widget/menu`, `InputDialog`, `ButtonDialog`, `ConfirmBox`, `InfoMessage`, `DateTimeWidget`, `ReaderHighlight:addToHighlightDialog`, `gettext`.
- **Datos en disco**: un archivo nuevo en el directorio de ajustes de KOReader. No se modifica `G_reader_settings` ni ningún `DocSettings`.
- **Dependencias externas**: ninguna. El plugin usa solo módulos que KOReader ya incluye.
- **Entorno de desarrollo**: requiere el emulador de KOReader (`kodev`) para las pruebas manuales y `busted` más `luacheck` para las automáticas.
- **Riesgo principal**: variaciones de API entre versiones de KOReader. Se acota ciñéndose a interfaces que ya usan los plugins del núcleo y verificando tres detalles concretos antes de implementar (ver `design.md`).
