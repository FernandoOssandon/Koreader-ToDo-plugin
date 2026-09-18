## Context

Ver `proposal.md` — sección Why para la motivación.

El proyecto arranca en verde: no hay código previo ni especificaciones anteriores. El anfitrión es KOReader, una aplicación Lua cuya extensibilidad está acotada por convenciones estables pero no formalmente versionadas. Las restricciones que condicionan el diseño son:

- **Reconocimiento del plugin**: un directorio se carga como plugin si su nombre termina en `.koplugin` y contiene un `main.lua`. `_meta.lua` aporta nombre y descripción sin cargar la lógica completa.
- **Hardware e-ink**: los refrescos completos de pantalla son lentos y visualmente molestos, y el dispositivo puede suspenderse o quedarse sin batería sin cierre ordenado.
- **Sin dependencias nuevas**: cualquier biblioteca externa complicaría la instalación manual, que es el mecanismo de distribución real de los plugins de terceros.
- **API disponible verificada** contra el código fuente actual de KOReader: `WidgetContainer:extend`, `self.ui.menu:registerToMainMenu(self)` con `addToMainMenu(menu_items)`, `Dispatcher:registerAction()` dentro de `onDispatcherRegisterActions()`, `LuaSettings:open(DataStorage:getSettingsDir() .. "/<archivo>.lua")` con `:flush()`, el evento `onFlushSettings()`, el widget `ui/widget/menu` con `item_table`/`onMenuSelect`/`onMenuHold`/`switchItemTable()`, los diálogos `InputDialog`/`ButtonDialog`/`ConfirmBox`/`InfoMessage`/`DateTimeWidget`, y `ReaderHighlight:addToHighlightDialog(idx, fn_button)` con el texto en `selected_text.text`.

## Goals / Non-Goals

**Goals:**

- Mantener la lógica de datos separada de la interfaz, de modo que los requisitos de `task-management` y `task-storage` sean verificables con pruebas automáticas sin arrancar la interfaz gráfica.
- Usar exclusivamente APIs que ya consumen plugins del núcleo de KOReader, para reducir la exposición a cambios entre versiones.
- Dejar el formato de datos preparado para evolucionar sin romper instalaciones existentes.
- Minimizar los refrescos completos de pantalla en la operación más frecuente (marcar una tarea).

**Non-Goals:**

- Diseñar un widget de lista propio. Se reutiliza el existente aunque imponga límites de presentación.
- Optimizar para volúmenes de miles de tareas. El diseño apunta a cientos.
- Abstraer el almacenamiento tras una capa que permita cambiar de motor. Si más adelante hiciera falta una base de datos, se migrará entonces.

## Decisions

### D1. Almacén propio en un archivo `LuaSettings`, no en los ajustes globales

Las tareas viven en `DataStorage:getSettingsDir() .. "/todolist.lua"`.

*Por qué*: aísla los datos del plugin, permite respaldarlos y borrarlos por separado, y hace que el versionado de esquema sea responsabilidad exclusiva del plugin. Guardar en `G_reader_settings` contamina los ajustes generales del usuario y complica la migración. `LuaSettings` es el mismo mecanismo que usa el plugin de perfiles del núcleo, así que no introduce nada nuevo.

*Alternativa descartada*: SQLite mediante `lua-ljsqlite3`, como hace el plugin de estadísticas. Añade complejidad de esquema y manejo de conexiones que el volumen previsto no justifica.

### D2. Una única lista global; el vínculo al libro es un campo opcional de la tarea

*Por qué*: el requisito de filtrar "de este libro" se satisface igual con un campo `book` en cada tarea, mientras que guardar listas separadas por documento (en los datos por documento de KOReader) haría imposible la vista global sin recorrer todos los libros del dispositivo. Además, una tarea puede nacer de un libro y seguir siendo relevante cuando ese libro ya no está.

*Coste asumido*: el filtro por libro exige comparar rutas de archivo, que pueden cambiar si el usuario reorganiza su biblioteca. Se acepta: el vínculo se degrada a "libro no disponible", tal como exige `koreader-integration`.

### D3. Frontera estricta entre datos e interfaz

`todostore.lua` implementa carga, volcado, CRUD, filtros y ordenación, y tiene prohibido hacer `require` de cualquier módulo bajo `ui/widget/`. La interfaz (`todolistview.lua`, `todoeditdialog.lua`) nunca escribe en el archivo: llama al almacén y se refresca con el resultado.

*Por qué*: es lo que permite ejecutar las pruebas de `busted` sobre Lua puro. Sin esa frontera, verificar la migración de esquema o el manejo de un archivo corrupto exigiría levantar el emulador.

### D4. Reutilizar el widget `Menu` en lugar de construir uno propio

Cada tarea se proyecta a una entrada de `item_table` con `text` (marcador textual `[ ]` / `[x]` más el título), `mandatory` (fecha límite abreviada), `bold` (prioridad alta) y `dim` (hecha).

*Por qué*: el widget ya resuelve paginación, gestos y coherencia estética con el resto de la aplicación. Los marcadores textuales, en lugar de iconos, funcionan con cualquier tema y tamaño de fuente sin añadir recursos gráficos.

*Alternativa descartada*: widget compuesto a medida. Coste alto para el MVP; queda disponible si la presentación resulta insuficiente.

### D5. Volcado inmediato tras cada mutación, con `onFlushSettings()` como red de seguridad

*Por qué*: el requisito de supervivencia a un apagado abrupto no se puede satisfacer volcando solo al salir, porque en un e-reader el cierre ordenado no está garantizado. El coste de escribir un archivo pequeño tras cada operación es despreciable frente al riesgo de perder datos. `onFlushSettings()` se mantiene por si alguna ruta de código deja cambios sin volcar.

### D6. Reparto de gestos: pulsación corta alterna el estado, pulsación larga abre las acciones

*Por qué*: marcar una tarea como hecha es, con diferencia, la operación más frecuente, y debe costar un solo toque. El resto de operaciones —editar, fecha, prioridad, ir al libro, eliminar— se agrupan en un diálogo de botones bajo pulsación larga. Además, alternar el estado solo cambia una fila, lo que permite un refresco parcial de pantalla en vez de reconstruir la lista entera.

*Alternativa descartada*: pulsación corta abre la edición. Convertiría la acción más común en la más cara y forzaría un refresco completo cada vez.

### D7. Esquema versionado desde la primera versión

El archivo lleva un campo `version` y el almacén mantiene una tabla `migrations[n]` aplicada en orden. Un archivo con versión mayor que la soportada se carga en modo solo lectura.

*Por qué*: añadir el versionado después obliga a adivinar el formato de los archivos ya escritos. El modo solo lectura ante una versión futura protege a quien sincroniza su directorio de ajustes entre dispositivos con versiones distintas del plugin.

### D8. Modelo de datos

```lua
{
    version = 1,
    next_id = 7,
    tasks = {
        {
            id = 6, title = "...", done = false, priority = 2,
            created = 1758067200, due = nil, completed = nil, notes = "",
            book = { path = "...", title = "...", page = 142 },  -- opcional
        },
    },
    view = { filter = "pending", sort = "created" },  -- estado de navegación persistente
}
```

Invariantes: `id` nunca se reutiliza y `next_id` solo crece; `done == true` implica `completed ~= nil`; `book.path` puede apuntar a un archivo inexistente.

### D9. Estructura de archivos

```
todolist.koplugin/
├── _meta.lua            -- nombre y descripción para Ajustes → Plugins
├── main.lua             -- ciclo de vida, menú, dispatcher, eventos
├── todostore.lua        -- datos y persistencia (sin interfaz)
├── todolistview.lua     -- pantalla de lista
├── todoeditdialog.lua   -- alta y edición
└── README.md
```

La entrada de menú usa `sorting_hint = "more_tools"`, que la sitúa bajo *Herramientas → Más herramientas*, donde el usuario ya espera encontrar plugins de terceros. Una entrada sin `sorting_hint` acabaría en el primer menú con el prefijo `"NEW: "`.

## Risks / Trade-offs

- **Cambios de API entre versiones de KOReader** → Ceñirse a interfaces que consumen plugins del núcleo (perfiles, constructor de vocabulario) y verificar los puntos abiertos de más abajo contra la versión objetivo antes de escribir código.
- **Refrescos completos de pantalla al operar sobre la lista** → D6 concentra la operación frecuente en un cambio de una sola fila; la reconstrucción íntegra queda reservada a los cambios de filtro y de orden, que el usuario percibe como cambios de contexto.
- **Escritura en disco tras cada mutación en almacenamiento lento** → El archivo es pequeño y las mutaciones son interactivas, nunca en lote. Si aparece latencia perceptible, la alternativa es agrupar las escrituras con un temporizador corto, no volver al volcado al salir.
- **Archivo de datos corrupto** → Carga defensiva con `pcall` y copia `.bak` antes de cada escritura, tal como exige `task-storage`.
- **El filtro "de este libro" falla si el usuario mueve sus archivos** → Se compara por ruta y se degrada a "libro no disponible" sin perder la tarea. Guardar además el título del libro permite al menos identificarlo.
- **Colisión de la entrada en el diálogo de selección con otro plugin** → El índice de registro determina el orden de los botones; se usa un prefijo poco frecuente (`12_todolist`) y se verifica en el emulador con los plugins habituales activos.
- **Un único archivo global crece sin límite** → Sin purga automática en la v1. Si el archivo se vuelve grande, la ordenación y el filtrado en memoria seguirán siendo viables en el rango de cientos de tareas previsto.

## Migration Plan

No hay datos previos que migrar: es la primera versión del plugin.

- **Despliegue**: copiar la carpeta `todolist.koplugin` al directorio de plugins (`koreader/plugins/` en Kobo y Kindle, `/sdcard/koreader/plugins/` en Android, `~/.config/koreader/plugins/` en Linux) y reiniciar la aplicación. También se respeta el ajuste `extra_plugin_paths` si está configurado.
- **Reversión**: desactivar el plugin desde *Ajustes → Plugins*, o borrar su carpeta. En ambos casos el archivo de datos permanece, de modo que reinstalar recupera las tareas.
- **Evolución futura**: cada cambio de formato incrementa `version` y añade una entrada a `migrations`. La migración se aplica al abrir y se vuelca antes de usar los datos.

## Open Questions

Resueltas leyendo el código de KOReader en `master` durante la tarea 1.3. Se dejan documentadas con su respuesta porque condicionan decisiones visibles en el código.

1. **¿Expone el widget `Menu` un icono derecho en su barra de título?** — **No.** `Menu` solo define `title_bar_left_icon`, y al construir su `TitleBar` le pasa `left_icon`, `left_icon_tap_callback` y `left_icon_hold_callback`, pero ningún `right_icon` ni su callback (solo `right_icon_size_ratio`, que sin icono no hace nada). *Variante elegida*: el icono izquierdo abre filtros y ordenación, y el alta de tareas es una primera fila fija de la lista (`+ Nueva tarea`).
2. **¿Qué firma tiene `DateTimeWidget`?** — Acepta `year`, `month`, `day`, `hour` y `min` como campos de entrada, además de `title_text`, `info_text`, `ok_text` y `cancel_text`, e invoca `callback(time)` con una tabla que trae los valores elegidos. *Variante elegida*: se usa directamente con `year`/`month`/`day`; la fecha límite se almacena como el epoch de las 23:59:59 de ese día, para que una tarea no se marque vencida el mismo día de su plazo.
3. **¿`Menu:switchItemTable()` conserva la posición?** — **Sí.** Su firma es `switchItemTable(new_title, new_item_table, itemnumber, itemmatch, new_subtitle)`, con `itemnumber` como tercer argumento. *Variante elegida*: los cambios que alteran el conjunto de la lista (filtro, orden, alta, borrado) usan `switchItemTable` con el índice a preservar; la alternancia de estado de una sola tarea muta su fila y llama a `updateItems(idx)`, que no reconstruye la tabla.
