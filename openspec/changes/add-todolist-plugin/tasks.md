## 1. Preparación del entorno

- [ ] 1.1 Clonar KOReader y compilar el emulador con `./kodev fetch-thirdparty` y `./kodev build`; verificar que `./kodev run` arranca y muestra el gestor de archivos
- [ ] 1.2 Activar el plugin de ejemplo `hello.koplugin` (quitando su bloque `if true then return { disabled = true } end`) y verificar que su entrada aparece en el menú; confirma que el ciclo editar → reiniciar → ver cambios funciona
- [x] 1.3 Resolver las tres Open Questions de `design.md` leyendo `frontend/ui/widget/menu.lua`, `frontend/ui/widget/datetimewidget.lua` y la firma de `switchItemTable` en la versión objetivo; anotar en `design.md` la respuesta y la variante elegida para cada una

## 2. Esqueleto del plugin

- [ ] 2.1 Crear `todolist.koplugin/_meta.lua` con `fullname` y `description` traducibles; verificar que el plugin aparece listado en Ajustes → Plugins tras reiniciar
- [ ] 2.2 Crear `todolist.koplugin/main.lua` con `WidgetContainer:extend{ name = "todolist", is_doc_only = false }`, `init()` y `addToMainMenu()` mostrando un `InfoMessage`; verificar que la entrada aparece bajo Herramientas → Más herramientas tanto en el gestor de archivos como con un libro abierto
- [ ] 2.3 Implementar `onDispatcherRegisterActions()` registrando `todolist_show`; verificar que la acción es asignable a un gesto desde Ajustes → Gestos y que al ejecutarla se muestra el mensaje

## 3. Almacén de datos

- [x] 3.1 Implementar `todostore.lua` con `open`, `get`, `add`, `update`, `remove`, `toggle`, `counts` y `flush` sobre `LuaSettings` en `DataStorage:getSettingsDir() .. "/todolist.lua"`; verificar con pruebas `busted` que `add` asigna identificadores crecientes y que `remove` sobre un identificador inexistente no lanza error
- [x] 3.2 Implementar las invariantes del modelo: rechazo de títulos vacíos o solo con espacios, y `completed` fijado al marcar hecha y limpiado al reabrir; verificar con pruebas `busted` que cubren los escenarios de `task-management`
- [x] 3.3 Implementar `SCHEMA_VERSION`, la tabla `migrations` y el modo solo lectura ante una versión superior; verificar con pruebas `busted` que un almacén de versión menor se migra y uno de versión mayor no admite escrituras
- [x] 3.4 Implementar la carga defensiva con `pcall`, el almacén ausente como lista vacía y la copia `.bak` previa a cada escritura; verificar con pruebas `busted` que un archivo con contenido ilegible no lanza excepción y que la copia se genera
- [ ] 3.5 Conectar el volcado inmediato tras cada mutación y añadir `onFlushSettings()` en `main.lua`; verificar en el emulador que tras crear una tarea y matar el proceso sin cierre ordenado la tarea sigue presente al reabrir

## 4. Pantalla de lista

- [ ] 4.1 Implementar `todolistview.lua` sobre el widget `Menu` con `is_popout = false`, `is_borderless = true` y `covers_fullscreen = true`, proyectando cada tarea a `text`, `mandatory`, `bold` y `dim`; verificar en el emulador que se listan las tareas con su estado y que las hechas se distinguen
- [ ] 4.2 Implementar el mensaje de lista vacía; verificar en el emulador que al abrir la lista sin tareas se explica cómo crear la primera en lugar de mostrar una pantalla en blanco
- [ ] 4.3 Implementar la alternancia de estado con pulsación corta y refresco de la fila afectada; verificar en el emulador que tras marcar una tarea en la tercera página se permanece en esa página con la tarea a la vista
- [ ] 4.4 Implementar el alta rápida con `InputDialog` desde la fila fija `+ Nueva tarea`; verificar en el emulador el ciclo completo crear → marcar → reiniciar KOReader → los estados persisten
- [ ] 4.5 Comprobar el rendimiento con un almacén sembrado de 200 tareas; verificar que la apertura de la lista y el paso de página no presentan bloqueo perceptible

## 5. Edición y borrado

- [ ] 5.1 Implementar el `ButtonDialog` contextual bajo pulsación larga con las acciones Editar, Fecha límite, Prioridad, Ir al libro y Eliminar; verificar en el emulador que se abre sobre cualquier tarea y que Ir al libro aparece deshabilitada en tareas sin vínculo
- [ ] 5.2 Implementar `todoeditdialog.lua` con edición de título y notas; verificar en el emulador que un título vaciado se rechaza conservando el anterior y mostrando un aviso
- [ ] 5.3 Implementar el borrado con `ConfirmBox`; verificar en el emulador que cancelar deja la tarea intacta y que confirmar solo elimina la seleccionada

## 6. Integración con el lector

- [ ] 6.1 Implementar la fecha límite con la variante de entrada elegida en 1.3, incluida la opción «sin fecha»; verificar en el emulador que una tarea pendiente con fecha pasada se señala como vencida y que al quitarle la fecha deja de estarlo
- [ ] 6.2 Implementar los tres niveles de prioridad y el destacado visual de la prioridad alta; verificar en el emulador que la diferencia es perceptible en la lista
- [ ] 6.3 Implementar el campo `book` y la acción «ir al libro», abriendo el documento por la página registrada; verificar en el emulador el salto correcto y que un libro borrado produce un aviso sin fallo y conservando la tarea
- [ ] 6.4 Registrar el botón en el diálogo de selección mediante `self.ui.highlight:addToHighlightDialog("12_todolist", ...)` usando `util.cleanupSelectedText`; verificar en el emulador que una selección multilínea genera un título sin saltos de línea ni espacios duplicados, vinculado al libro y la página
- [ ] 6.5 Registrar las acciones `todolist_add` y `todolist_add_from_book` en el dispatcher; verificar asignando cada una a un gesto y comprobando que la segunda previncula el libro y la página en curso

## 7. Filtros, orden y presentación

- [x] 7.1 Implementar en `todostore.lua` el filtrado por todas, pendientes, hechas, vencidas y de este libro; verificar con pruebas `busted` que cada filtro devuelve el subconjunto esperado
- [x] 7.2 Implementar la ordenación por creación, fecha límite, prioridad y alfabético, agrupando al final las tareas sin fecha; verificar con pruebas `busted` que cubren cada criterio
- [ ] 7.3 Exponer filtros y orden desde el icono izquierdo de la barra de título y reflejar el filtro activo y el recuento en el encabezado; verificar en el emulador que el encabezado muestra el filtro y el número de tareas mostradas sobre el total
- [ ] 7.4 Persistir el filtro y el orden activos en el campo `view` del almacén; verificar en el emulador que sobreviven a un reinicio de KOReader
- [ ] 7.5 Ocultar o inhabilitar el filtro «de este libro» cuando no hay documento abierto; verificar en el emulador que abrir la lista desde el gestor de archivos no produce ningún error
- [ ] 7.6 Implementar el recuento de pendientes en el texto de la entrada de menú mediante `text_func`; verificar en el emulador que muestra el número con tareas pendientes y lo omite cuando no hay ninguna

## 8. Pulido y publicación

- [ ] 8.1 Envolver todas las cadenas visibles en `_()` y usar `T()` para las que llevan sustitución, sin concatenar fragmentos traducibles; verificar revisando que no queda ninguna cadena literal en la interfaz
- [x] 8.2 Ejecutar `luacheck` con la configuración del repositorio de KOReader sobre `todolist.koplugin/`; verificar que termina sin avisos
- [x] 8.3 Ejecutar la suite completa de `busted` sobre `todostore.lua`; verificar que todos los escenarios de `task-management` y `task-storage` pasan
- [ ] 8.4 Escribir `README.md` con las rutas de instalación por plataforma, el uso y capturas; verificar que alguien ajeno al proyecto puede instalarlo siguiendo solo ese documento
- [ ] 8.5 Recorrer el guion de regresión completo en un dispositivo e-ink real, con y sin libro abierto; verificar que no aparecen errores en `crash.log` tras una sesión de uso normal
- [ ] 8.6 Comprobar la desactivación y reactivación del plugin desde Ajustes → Plugins; verificar que desaparecen menú, gestos y botón de selección, y que al reactivarlo las tareas guardadas siguen estando
