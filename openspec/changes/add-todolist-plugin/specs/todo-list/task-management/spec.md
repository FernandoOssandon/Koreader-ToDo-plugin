## Purpose

Define el ciclo de vida de una tarea de la lista de pendientes: cómo se crea, qué campos tiene, cómo cambia entre pendiente y hecha, cómo se edita y cómo se elimina, junto con las reglas de validación que mantienen los datos coherentes.

## ADDED Requirements

### Requirement: Creación de tareas

El sistema SHALL permitir crear una tarea a partir de un título. Cada tarea creada MUST recibir un identificador único que no se reutiliza nunca, la marca de tiempo de creación, el estado inicial "pendiente" y la prioridad "normal" salvo que se indique otra.

#### Scenario: Alta con título válido
- **WHEN** la persona confirma el alta con el título "Revisar la cita del capítulo 3"
- **THEN** la tarea aparece en la lista como pendiente, con prioridad normal y sin fecha límite

#### Scenario: Alta con título vacío
- **WHEN** la persona confirma el alta con el campo de título vacío o compuesto solo por espacios
- **THEN** no se crea ninguna tarea y la persona recibe un aviso explicando que el título es obligatorio

#### Scenario: Los identificadores no se reutilizan
- **WHEN** se crea una tarea, se elimina y a continuación se crea otra
- **THEN** la nueva tarea recibe un identificador distinto del que tuvo la eliminada

### Requirement: Alternancia entre pendiente y hecha

El sistema SHALL permitir marcar una tarea pendiente como hecha y devolver una tarea hecha al estado pendiente. Una tarea hecha MUST registrar la marca de tiempo de completado, y esa marca MUST desaparecer al devolverla a pendiente.

#### Scenario: Marcar una tarea como hecha
- **WHEN** la persona marca como hecha una tarea pendiente
- **THEN** la tarea queda registrada como hecha con la fecha y hora de ese momento

#### Scenario: Reabrir una tarea hecha
- **WHEN** la persona devuelve a pendiente una tarea que estaba hecha
- **THEN** la tarea vuelve a contarse como pendiente y deja de tener fecha de completado

### Requirement: Edición de los campos de una tarea

El sistema SHALL permitir modificar el título, las notas, la prioridad y la fecha límite de una tarea existente. Una edición que dejara el título vacío MUST rechazarse y conservar el valor anterior.

#### Scenario: Cambiar el título
- **WHEN** la persona edita el título de una tarea y guarda
- **THEN** la lista muestra el título nuevo y el resto de campos permanece igual

#### Scenario: Quitar la fecha límite
- **WHEN** la persona elige "sin fecha" en una tarea que tenía fecha límite
- **THEN** la tarea deja de tener fecha límite y deja de poder considerarse vencida

#### Scenario: Edición que vaciaría el título
- **WHEN** la persona borra todo el título de una tarea existente e intenta guardar
- **THEN** el cambio se rechaza, la tarea conserva su título anterior y la persona recibe un aviso

### Requirement: Eliminación de tareas

El sistema SHALL permitir eliminar una tarea, y MUST pedir confirmación explícita antes de hacerlo. La eliminación MUST afectar únicamente a la tarea seleccionada.

#### Scenario: Eliminación confirmada
- **WHEN** la persona elige eliminar una tarea y confirma
- **THEN** la tarea desaparece de la lista y las demás tareas permanecen intactas

#### Scenario: Eliminación cancelada
- **WHEN** la persona elige eliminar una tarea y cancela la confirmación
- **THEN** la tarea sigue presente y sin cambios

### Requirement: Fecha límite y vencimiento

El sistema SHALL permitir asignar una fecha límite opcional. Una tarea SHALL considerarse vencida únicamente si está pendiente y su fecha límite es anterior al momento actual. Una tarea sin fecha límite MUST no considerarse vencida nunca.

#### Scenario: Tarea pendiente con fecha pasada
- **WHEN** la lista se consulta después de la fecha límite de una tarea pendiente
- **THEN** esa tarea se presenta como vencida

#### Scenario: Tarea hecha con fecha pasada
- **WHEN** la lista se consulta después de la fecha límite de una tarea ya marcada como hecha
- **THEN** esa tarea no se presenta como vencida

#### Scenario: Tarea sin fecha límite
- **WHEN** la lista se consulta con una tarea pendiente que no tiene fecha límite
- **THEN** esa tarea no se presenta como vencida en ningún momento

### Requirement: Prioridad de las tareas

El sistema SHALL ofrecer tres niveles de prioridad —alta, normal y baja— y MUST distinguir visualmente las tareas de prioridad alta en la lista.

#### Scenario: Asignar prioridad alta
- **WHEN** la persona marca una tarea con prioridad alta
- **THEN** la tarea se distingue visualmente del resto en la lista y puede usarse como criterio de ordenación
