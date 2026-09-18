## Purpose

Describe cómo se presenta la lista de tareas y cómo se navega por ella: qué información muestra cada entrada, qué filtros y criterios de ordenación existen, y qué estado de navegación se conserva entre interacciones y entre sesiones.

## ADDED Requirements

### Requirement: Presentación de la lista

El sistema SHALL mostrar las tareas en una lista paginada. Cada entrada MUST indicar si la tarea está pendiente o hecha, su título y su fecha límite cuando la tenga. Las tareas hechas MUST distinguirse visualmente de las pendientes, y las vencidas MUST señalarse como tales.

#### Scenario: Lista con tareas en distintos estados
- **WHEN** la persona abre la lista con tareas pendientes, hechas y vencidas
- **THEN** cada entrada muestra su estado y su título, las hechas se distinguen de las pendientes y las vencidas quedan señaladas

#### Scenario: Lista vacía
- **WHEN** la persona abre la lista y no hay ninguna tarea que mostrar con el filtro activo
- **THEN** se muestra un mensaje que explica la situación en lugar de una pantalla en blanco

### Requirement: Filtrado de tareas

El sistema SHALL ofrecer los filtros "todas", "pendientes", "hechas", "vencidas" y "de este libro". El filtro activo MUST ser visible sin necesidad de abrir ningún menú, y MUST conservarse entre sesiones.

#### Scenario: Aplicar un filtro
- **WHEN** la persona selecciona el filtro "pendientes"
- **THEN** la lista muestra únicamente tareas pendientes y el encabezado indica el filtro activo y el número de tareas mostradas sobre el total

#### Scenario: El filtro sobrevive al reinicio
- **WHEN** la persona deja activo el filtro "vencidas", cierra la aplicación y vuelve a abrir la lista
- **THEN** el filtro "vencidas" sigue activo

#### Scenario: Filtro por libro fuera del lector
- **WHEN** la persona abre la lista desde el gestor de archivos, sin ningún libro abierto
- **THEN** el filtro "de este libro" no está disponible o se indica que no es aplicable, sin provocar ningún error

### Requirement: Ordenación de tareas

El sistema SHALL permitir ordenar la lista por fecha de creación, fecha límite, prioridad y orden alfabético. El criterio elegido MUST conservarse entre sesiones.

#### Scenario: Ordenar por fecha límite
- **WHEN** la persona elige ordenar por fecha límite
- **THEN** las tareas con fecha más próxima aparecen primero y las que no tienen fecha se agrupan al final

#### Scenario: El orden sobrevive al reinicio
- **WHEN** la persona elige ordenar por prioridad, cierra la aplicación y vuelve a abrir la lista
- **THEN** la lista sigue ordenada por prioridad

### Requirement: Recuento de tareas pendientes

El sistema SHALL mostrar el número de tareas pendientes en el punto de entrada del menú, de modo que sea visible sin abrir la lista. El recuento MUST reflejar el estado actual y MUST omitirse cuando no hay ninguna tarea pendiente.

#### Scenario: Hay tareas pendientes
- **WHEN** existen cuatro tareas pendientes
- **THEN** el punto de entrada del menú muestra el título junto al número cuatro

#### Scenario: No hay tareas pendientes
- **WHEN** todas las tareas están hechas o no hay ninguna tarea
- **THEN** el punto de entrada del menú muestra el título sin ningún recuento

### Requirement: Preservación del estado de navegación

Tras una operación sobre una tarea concreta, el sistema SHALL mantener a la persona en la misma página de la lista y con la misma tarea a la vista. Alternar el estado de una sola tarea MUST no provocar la reconstrucción visible de toda la lista.

#### Scenario: Marcar una tarea en una página avanzada
- **WHEN** la persona navega a la tercera página de la lista y marca una tarea como hecha
- **THEN** la lista sigue mostrando la tercera página con esa tarea visible y su nuevo estado

#### Scenario: Volver de la edición
- **WHEN** la persona edita una tarea y guarda los cambios
- **THEN** vuelve a la misma posición de la lista desde la que abrió la edición
