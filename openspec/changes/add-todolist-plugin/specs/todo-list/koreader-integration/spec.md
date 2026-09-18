## Purpose

Define los puntos de contacto entre la lista de tareas y la aplicación anfitriona: cómo se llega a la lista desde la interfaz y desde los gestos, cómo se captura una tarea mientras se lee y cómo se vuelve desde una tarea al punto exacto del libro que la originó.

## ADDED Requirements

### Requirement: Punto de entrada en el menú principal

El sistema SHALL añadir una entrada al menú principal que abre la lista de tareas. Esa entrada MUST estar disponible tanto en el gestor de archivos como durante la lectura de un documento.

#### Scenario: Acceso desde el gestor de archivos
- **WHEN** la persona abre el menú principal en el gestor de archivos y selecciona la entrada de la lista de tareas
- **THEN** se abre la lista de tareas

#### Scenario: Acceso durante la lectura
- **WHEN** la persona abre el menú principal con un documento abierto y selecciona la entrada de la lista de tareas
- **THEN** se abre la lista de tareas sin cerrar el documento, y al salir de ella vuelve a la misma página

### Requirement: Acciones asignables a gestos

El sistema SHALL exponer como acciones asignables "abrir la lista", "crear tarea rápida" y "crear tarea vinculada al libro actual", de modo que puedan asociarse a gestos y perfiles.

#### Scenario: Gesto para abrir la lista
- **WHEN** la persona asocia la acción "abrir la lista" a un gesto y lo ejecuta
- **THEN** se abre la lista de tareas

#### Scenario: Gesto para crear una tarea vinculada
- **WHEN** la persona ejecuta el gesto de "crear tarea vinculada al libro actual" mientras lee
- **THEN** se ofrece introducir un título y la tarea resultante queda vinculada al libro y a la página en curso

### Requirement: Creación de tareas desde una selección de texto

Durante la lectura, el sistema SHALL ofrecer crear una tarea a partir del texto seleccionado. El texto seleccionado MUST usarse como título inicial, normalizado para eliminar saltos de línea y espacios sobrantes, y la tarea resultante MUST quedar vinculada al libro y la página de la selección.

#### Scenario: Crear tarea desde una selección
- **WHEN** la persona selecciona un fragmento de texto y elige la opción de añadirlo a la lista de tareas
- **THEN** se crea una tarea cuyo título es ese fragmento normalizado, vinculada al libro y la página actuales, y el diálogo de selección se cierra

#### Scenario: Selección multilínea
- **WHEN** el texto seleccionado abarca varias líneas del documento
- **THEN** el título de la tarea creada no contiene saltos de línea ni espacios duplicados

### Requirement: Vínculo entre una tarea y una posición de lectura

Una tarea SHALL poder estar vinculada a un libro y una página. Desde una tarea vinculada, el sistema MUST permitir abrir ese libro por esa página. Si el libro ya no está disponible, MUST informar a la persona sin fallar y MUST conservar la tarea.

#### Scenario: Volver al libro
- **WHEN** la persona elige "ir al libro" en una tarea vinculada y el archivo existe
- **THEN** se abre ese libro por la página registrada en la tarea

#### Scenario: El libro ya no existe
- **WHEN** la persona elige "ir al libro" en una tarea cuyo archivo ha sido borrado del dispositivo
- **THEN** recibe un aviso de que el libro no está disponible, la aplicación no falla y la tarea se conserva con su vínculo

#### Scenario: Tarea sin vínculo
- **WHEN** la persona abre las acciones de una tarea que no está vinculada a ningún libro
- **THEN** la opción de ir al libro no se ofrece o aparece deshabilitada

### Requirement: Instalación y desactivación como plugin

El sistema SHALL distribuirse como un plugin autocontenido que se instala copiando una carpeta al directorio de plugins de la aplicación, sin modificar sus archivos. MUST poder desactivarse desde los ajustes de plugins, y al desactivarlo los datos de las tareas MUST conservarse.

#### Scenario: Instalación
- **WHEN** la persona copia la carpeta del plugin al directorio de plugins y reinicia la aplicación
- **THEN** la lista de tareas aparece en el menú principal sin que haya sido necesario modificar ningún archivo de la aplicación

#### Scenario: Desactivación
- **WHEN** la persona desactiva el plugin desde los ajustes y reinicia la aplicación
- **THEN** desaparecen su entrada de menú, sus acciones asignables y su opción en el diálogo de selección, y al reactivarlo las tareas guardadas siguen estando
