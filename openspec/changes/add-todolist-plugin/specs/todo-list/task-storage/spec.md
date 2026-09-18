## Purpose

Garantiza que las tareas sobreviven a reinicios, apagados abruptos y actualizaciones del plugin, definiendo el versionado del almacén de datos, su migración y el comportamiento ante datos ausentes, corruptos o escritos por una versión más reciente.

## ADDED Requirements

### Requirement: Persistencia entre sesiones

El sistema SHALL conservar las tareas entre reinicios de la aplicación. Los cambios MUST quedar escritos en almacenamiento persistente inmediatamente después de cada operación que los produce, sin depender de un cierre ordenado de la aplicación.

#### Scenario: Reinicio ordenado
- **WHEN** la persona crea varias tareas, cierra la aplicación con normalidad y vuelve a abrirla
- **THEN** la lista muestra exactamente las mismas tareas con los mismos estados

#### Scenario: Apagado abrupto
- **WHEN** la persona marca una tarea como hecha y el dispositivo se apaga sin cierre ordenado
- **THEN** al volver a abrir la aplicación la tarea sigue marcada como hecha

### Requirement: Aislamiento del almacén de datos

El sistema SHALL guardar las tareas en un almacén propio y exclusivo. MUST no escribir tareas en los ajustes generales de la aplicación ni en los datos asociados a un documento concreto.

#### Scenario: Los ajustes generales no se tocan
- **WHEN** se realizan operaciones de alta, edición y borrado de tareas
- **THEN** los ajustes generales de la aplicación y los datos por documento permanecen sin modificar

### Requirement: Esquema versionado y migración

El almacén de datos SHALL registrar la versión de su esquema. Al abrirlo, el sistema MUST migrar los datos escritos por una versión anterior antes de usarlos, y MUST tratar como solo lectura los datos escritos por una versión posterior, avisando a la persona.

#### Scenario: Datos de una versión anterior
- **WHEN** se abre un almacén cuya versión de esquema es menor que la soportada
- **THEN** los datos se migran al esquema actual, se guardan migrados y todas las tareas siguen accesibles

#### Scenario: Datos de una versión posterior
- **WHEN** se abre un almacén cuya versión de esquema es mayor que la soportada
- **THEN** las tareas se muestran pero no se permite modificarlas, y la persona recibe un aviso que explica el motivo

### Requirement: Carga defensiva

El sistema SHALL arrancar sin errores aunque el almacén no exista o su contenido sea ilegible. Un almacén ausente MUST tratarse como una lista vacía. Un almacén ilegible MUST no provocar un fallo de la aplicación, MUST avisar a la persona y MUST conservar el archivo original antes de sobrescribirlo.

#### Scenario: Primer uso
- **WHEN** se abre la lista por primera vez y no existe ningún almacén
- **THEN** se presenta una lista vacía con un mensaje que explica cómo crear la primera tarea

#### Scenario: Almacén ilegible
- **WHEN** se abre la lista y el contenido del almacén no puede interpretarse
- **THEN** la aplicación no falla, la persona recibe un aviso y el contenido original se conserva en una copia antes de escribir datos nuevos
