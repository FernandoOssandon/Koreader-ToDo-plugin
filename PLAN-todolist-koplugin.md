# Plan de implementación — `todolist.koplugin`

> Plugin de lista de tareas (to-do) para KOReader.
> Documento de planificación técnica. Versión 1 — 2026-09-17.

---

## 0. Resumen ejecutivo

Construir un plugin autocontenido `todolist.koplugin` que permita crear, consultar,
completar y eliminar tareas desde KOReader, tanto en el gestor de archivos como
dentro de un libro. Las tareas se guardan en un único archivo de configuración
propio (formato `LuaSettings`), pueden opcionalmente vincularse a un libro y una
página, y se pueden crear directamente desde una selección de texto mientras se lee.

El desarrollo se divide en **7 fases** incrementales; al final de cada una el plugin
queda instalable y funcional.

---

## 1. Objetivo y alcance

### 1.1 En alcance (MVP, fases 1–4)

- Crear tarea con título.
- Marcar tarea como hecha / pendiente.
- Editar título y notas.
- Eliminar tarea (con confirmación).
- Listado en pantalla completa con paginación.
- Persistencia entre reinicios de KOReader.
- Entrada en el menú principal y acción asignable a gesto.

### 1.2 En alcance (v1 completa, fases 5–7)

- Fecha límite (`DateTimeWidget`) y resaltado de tareas vencidas.
- Prioridad (alta / normal / baja).
- Vínculo opcional a libro + página, con salto al libro desde la tarea.
- Crear tarea desde una selección de texto en el lector.
- Filtros (todas / pendientes / hechas / vencidas / de este libro) y ordenación.
- Traducción vía `gettext`.

### 1.3 Fuera de alcance

- Sincronización con servicios externos (Todoist, CalDAV, Nextcloud…).
- Recordatorios con notificación programada (los lectores e-ink suspenden el proceso).
- Subtareas anidadas y tareas recurrentes.
- Adjuntos.

Estos puntos se registran en el backlog (§13) pero **no** condicionan el diseño del MVP
más allá de dejar el modelo de datos versionado (§5).

---

## 2. Base técnica verificada

API confirmada contra el código fuente actual de KOReader (`master`):

| Elemento | Detalle |
| --- | --- |
| Formato de plugin | Carpeta `<nombre>.koplugin/` con `main.lua` obligatorio y `_meta.lua` por convención |
| Clase base | `WidgetContainer:extend{ name = "...", is_doc_only = false }` |
| Menú principal | `self.ui.menu:registerToMainMenu(self)` en `init()` + método `addToMainMenu(menu_items)` |
| Ubicación en el menú | Campo `sorting_hint` en la entrada del menú |
| Gestos / acciones | `Dispatcher:registerAction(id, {category=, event=, title=, general=true})` dentro de `onDispatcherRegisterActions()` |
| Persistencia | `LuaSettings:open(DataStorage:getSettingsDir() .. "/<archivo>.lua")`, volcado con `:flush()` |
| Punto de volcado | Manejador de evento `onFlushSettings()` |
| Lista de UI | Widget `ui/widget/menu` con `item_table`, `onMenuSelect`, `onMenuHold`, `switchItemTable()` |
| Diálogos | `InputDialog`, `ButtonDialog`, `ConfirmBox`, `InfoMessage`, `DateTimeWidget` |
| Selección de texto | `self.ui.highlight:addToHighlightDialog(idx, fn_button)`; texto en `this.selected_text.text`, limpiar con `util.cleanupSelectedText()` |
| Traducción | `local _ = require("gettext")` |

### 2.1 Valores válidos de `sorting_hint`

Grupos disponibles en el orden de menú del lector: `navi`, `navi_settings`, `typeset`,
`setting`, `taps_and_gestures`, `document`, `device`, `navigation`, `network`, `screen`,
`tools`, `more_tools`, `search`, `search_settings`, `filemanager`, `main`, `help`, `exit_menu`.

**Decisión:** usar `sorting_hint = "more_tools"`, coherente con el resto de plugins de
terceros. Una entrada sin `sorting_hint` cae en el primer menú con el prefijo `"NEW: "`.

### 2.2 Rutas de instalación por dispositivo

| Plataforma | Ruta |
| --- | --- |
| Kobo / Kindle | `koreader/plugins/` |
| Android | `/sdcard/koreader/plugins/` |
| Linux (escritorio) | `~/.config/koreader/plugins/` |
| Emulador (`kodev`) | `koreader/plugins/` dentro del árbol de build |

También se respeta el ajuste `extra_plugin_paths` si el usuario lo tiene configurado.

### 2.3 Puntos a verificar contra la versión objetivo

Antes de fijar la implementación conviene confirmar en el KOReader instalado:

1. Nombre exacto del campo del icono derecho de la barra de título del widget `Menu`
   (el izquierdo es `title_bar_left_icon` + `onLeftButtonTap`). Si no existe equivalente
   derecho, el botón "añadir tarea" se resuelve con una primera fila fija en la lista.
2. Firma de `DateTimeWidget` (campos `year/month/day` vs `hour/min`) en la versión objetivo.
3. Disponibilidad de `Menu:switchItemTable()` con el tercer argumento `itemnumber`
   para conservar la posición de scroll tras una edición.

---

## 3. Decisiones de diseño

| Id | Decisión | Motivo | Alternativa descartada |
| --- | --- | --- | --- |
| D1 | Persistir en archivo propio `todolist.lua` vía `LuaSettings` | Aísla los datos de `G_reader_settings`; fácil de respaldar y de migrar | Guardar en `G_reader_settings` (contamina los ajustes globales) |
| D2 | Una sola lista global; el vínculo al libro es un campo opcional de la tarea | Permite una vista unificada y evita fragmentar datos en decenas de `DocSettings` | Una lista por libro en `DocSettings` (pierde la vista global) |
| D3 | Sin SQLite en el MVP | El volumen esperado (decenas o cientos de tareas) no lo justifica; menos dependencias | `lua-ljsqlite3`, como usa el plugin de estadísticas |
| D4 | Reutilizar el widget `Menu` en vez de un widget propio | Paginación, gestos y estética consistentes sin código extra | Widget compuesto a medida (coste alto; queda para fase posterior si hace falta) |
| D5 | Volcado a disco inmediato tras cada mutación, **además** de `onFlushSettings()` | Los e-readers se apagan o se quedan sin batería sin cierre limpio | Volcar solo al salir (riesgo de pérdida de datos) |
| D6 | Separar lógica de datos (`todostore.lua`) de la UI | Permite probar el CRUD con `busted` sin arrancar la interfaz | Todo en `main.lua` |
| D7 | Campo `version` en el archivo de datos desde el día 1 | Habilita migraciones sin romper instalaciones existentes | Sin versionado |

---

## 4. Estructura de archivos

```
todolist.koplugin/
├── _meta.lua            -- nombre y descripción mostrados en Ajustes → Plugins
├── main.lua             -- clase del plugin: init, menú, dispatcher, eventos
├── todostore.lua        -- modelo de datos + CRUD + persistencia (sin UI)
├── todolistview.lua     -- pantalla de lista (envuelve el widget Menu)
├── todoeditdialog.lua   -- diálogos de alta y edición de una tarea
└── README.md            -- instalación y uso
```

Regla: `todostore.lua` no debe hacer `require` de ningún módulo de `ui/widget/*`.
Esa frontera es lo que hace posibles las pruebas unitarias de §10.2.

---

## 5. Modelo de datos

Contenido del archivo `<settings>/todolist.lua`:

```lua
{
    version = 1,          -- esquema; habilita migraciones futuras
    next_id = 7,          -- contador monótono de ids
    tasks = {
        {
            id        = 6,
            title     = "Comparar traducciones del capítulo 3",
            done      = false,
            priority  = 2,              -- 1 alta, 2 normal, 3 baja
            created   = 1758067200,     -- epoch
            due       = 1758326400,     -- epoch o nil
            completed = nil,            -- epoch o nil
            notes     = "",
            book      = {               -- opcional
                path  = "/mnt/onboard/libro.epub",
                title = "El nombre de la rosa",
                page  = 142,
            },
        },
    },
}
```

### 5.1 Invariantes

- `id` es único y nunca se reutiliza; `next_id` solo crece.
- `done == true` implica `completed ~= nil`; al reabrir una tarea se pone `completed = nil`.
- `book.path` puede apuntar a un archivo que ya no existe: la interfaz debe degradar
  a "libro no disponible" en vez de fallar.
- Una tarea sin `due` nunca se considera vencida.

### 5.2 Migraciones

`TodoStore:load()` compara `version` con `SCHEMA_VERSION`. Si es menor, aplica en orden
las funciones de una tabla `migrations[n]` y vuelca el resultado. Si es mayor (archivo
escrito por una versión más nueva del plugin), se carga en modo solo lectura y se avisa
con un `InfoMessage`, para no corromper datos que este código no entiende.

---

## 6. Componentes y responsabilidades

| Módulo | Responsabilidad | Interfaz pública |
| --- | --- | --- |
| `main.lua` | Ciclo de vida del plugin, registro en menú y dispatcher, manejadores de evento | `init`, `addToMainMenu`, `onDispatcherRegisterActions`, `onShowTodoList`, `onFlushSettings` |
| `todostore.lua` | Carga y volcado, CRUD, filtros, ordenación, migraciones | `open`, `add`, `update`, `remove`, `toggle`, `get`, `list(filter, sort)`, `counts`, `flush` |
| `todolistview.lua` | Construir la `item_table` a partir del store y gestionar la interacción | `TodoListView:show(store, opts)` |
| `todoeditdialog.lua` | Alta y edición de una tarea (título, notas, fecha, prioridad) | `showAdd(store, defaults, on_done)`, `showEdit(store, task, on_done)` |

`todolistview` nunca escribe en el archivo directamente: siempre llama al store y
después se refresca con `switchItemTable()`.

---

## 7. Integración con KOReader

### 7.1 Menú principal

```lua
function TodoList:addToMainMenu(menu_items)
    menu_items.todo_list = {
        text_func = function()
            local pending = self.store:counts().pending
            return pending > 0
                and T(_("To-do list (%1)"), pending)
                or  _("To-do list")
        end,
        sorting_hint = "more_tools",
        callback = function() self:onShowTodoList() end,
    }
end
```

El contador de pendientes en el propio texto del menú es barato y aporta valor inmediato.

### 7.2 Acciones para gestos y perfiles

Dentro de `onDispatcherRegisterActions()`:

| Acción | Evento | Descripción |
| --- | --- | --- |
| `todolist_show` | `ShowTodoList` | Abrir la lista |
| `todolist_add` | `AddTodoTask` | Alta rápida (solo título) |
| `todolist_add_from_book` | `AddTodoTaskFromBook` | Alta previnculada al libro y página actuales |

Todas con `category = "none"` y `general = true`, para que aparezcan en el gestor de
gestos tanto del lector como del gestor de archivos.

### 7.3 Menú de selección de texto (solo lector)

En `init()`, si `self.ui.highlight` existe:

```lua
self.ui.highlight:addToHighlightDialog("12_todolist", function(this)
    return {
        text = _("Add to to-do list"),
        enabled = true,
        callback = function()
            local text = util.cleanupSelectedText(this.selected_text.text)
            self:addTaskFromSelection(text)
            this:onClose()
        end,
    }
end)
```

El prefijo numérico del índice controla la posición del botón dentro del diálogo.

### 7.4 Eventos

| Evento | Uso |
| --- | --- |
| `onFlushSettings` | Red de seguridad: volcar si quedó algo pendiente |
| `onDispatcherRegisterActions` | Registro de acciones (llamado desde `init`) |
| `onShowTodoList`, `onAddTodoTask`, … | Disparados por los gestos registrados |

---

## 8. Flujos de interfaz

### 8.1 Pantalla de lista

Widget `Menu` con `is_popout = false`, `is_borderless = true`, `covers_fullscreen = true`.

Cada entrada de `item_table`:

- `text`: `"[ ] título"` o `"[x] título"` (marcador textual; funciona con cualquier tema).
- `mandatory`: fecha límite abreviada, o cadena vacía.
- `bold`: `true` si la prioridad es alta.
- `dim`: `true` si la tarea está hecha.

Interacción:

| Gesto | Acción |
| --- | --- |
| Tap sobre una tarea | Alterna hecha/pendiente (la operación más frecuente) y refresca en sitio |
| Mantener pulsado | `ButtonDialog` contextual: Editar · Fecha límite · Prioridad · Ir al libro · Eliminar |
| Icono izquierdo de la barra de título | `ButtonDialog` de filtros y ordenación |
| Primera fila fija `+ Nueva tarea` | Diálogo de alta |
| Botón atrás / esquina | Cerrar (`onClose`) |

El título de la pantalla muestra el filtro activo y el recuento, por ejemplo
`"Pendientes (4 de 12)"`, de modo que el filtro nunca queda invisible.

### 8.2 Alta de tarea

`InputDialog` con un único campo de título y botones *Cancelar* / *Guardar*, más un
botón *Más…* que abre el diálogo de edición completo. Optimiza el caso común —anotar
algo rápido sin salir del libro— sin esconder el resto de campos.

### 8.3 Edición completa

Campos presentados como `ButtonDialog` o menú secundario: título (`InputDialog`),
notas (`InputDialog` multilínea), fecha límite (`DateTimeWidget`, con opción
*Sin fecha*), prioridad (tres botones) y vínculo al libro (añadir el libro actual /
quitar vínculo).

### 8.4 Eliminación

Siempre vía `ConfirmBox` con `ok_text = _("Delete")`. Sin papelera en la v1.

---

## 9. Fases de implementación

Cada fase termina con un plugin instalable y probado en el emulador.

### Fase 0 — Entorno (0,5 día)

- Clonar KOReader y compilar el emulador (`./kodev fetch-thirdparty && ./kodev build`).
- Verificar `./kodev run` y el ciclo editar → reiniciar → ver cambios.
- Confirmar los tres puntos abiertos de §2.3 leyendo el código de la versión objetivo.

**Criterio de aceptación:** el emulador arranca y muestra el plugin `hello` como activable.

### Fase 1 — Esqueleto cargable (0,5 día)

- `_meta.lua` con `fullname` y `description`.
- `main.lua` con `WidgetContainer:extend`, `init()`, `addToMainMenu()` que muestre un
  `InfoMessage`, y `onDispatcherRegisterActions()`.

**Criterio de aceptación:** el plugin aparece en *Ajustes → Plugins*, su entrada sale bajo
*Herramientas → Más herramientas* y la acción es asignable a un gesto.

### Fase 2 — Almacén de datos (1 día)

- `todostore.lua` completo: `open/add/update/remove/toggle/get/list/counts/flush`,
  `SCHEMA_VERSION`, tabla `migrations`, manejo de archivo inexistente o corrupto.
- Volcado inmediato tras cada mutación, más `onFlushSettings()` en `main.lua`.

**Criterio de aceptación:** pruebas unitarias en verde (§10.2); los datos sobreviven a un
reinicio de KOReader y a un cierre forzado del emulador.

### Fase 3 — Vista de lista (1,5 días)

- `todolistview.lua`: construcción de la `item_table`, tap para alternar estado,
  fila `+ Nueva tarea`, cierre correcto.
- Alta rápida con `InputDialog`.

**Criterio de aceptación:** flujo completo crear → marcar → reabrir KOReader con los
estados persistidos; navegación con más de 200 tareas sin bloqueo perceptible.

### Fase 4 — Edición y borrado (1 día)

- `ButtonDialog` contextual al mantener pulsado.
- `todoeditdialog.lua` con título y notas.
- Borrado con `ConfirmBox`.

**Criterio de aceptación:** MVP cerrado; todas las operaciones CRUD accesibles desde la interfaz.

### Fase 5 — Integración con el lector (1 día)

- Fecha límite con `DateTimeWidget` y prioridad.
- Campo `book` y acción *Ir al libro* (abre el documento y salta a la página; si el archivo
  no existe, `InfoMessage` explicativo).
- Botón en el diálogo de selección de texto.
- Acciones `todolist_add` y `todolist_add_from_book` en el dispatcher.

**Criterio de aceptación:** seleccionar texto en un EPUB crea una tarea vinculada y desde
ella se vuelve a la página exacta.

### Fase 6 — Filtros, orden y presentación (1 día)

- Filtros: todas / pendientes / hechas / vencidas / de este libro.
- Orden: creación, fecha límite, prioridad, alfabético.
- Filtro y orden se recuerdan entre sesiones (guardados en el propio archivo del plugin).
- Marca visual de vencidas y contador en la entrada del menú.

**Criterio de aceptación:** cambiar filtro u orden no pierde la posición de scroll ni
provoca refrescos completos de pantalla innecesarios.

### Fase 7 — Pulido y publicación (1 día)

- Todas las cadenas envueltas en `_()`; plurales con `N_()` donde corresponda.
- `luacheck` sin avisos.
- `README.md` con instalación por plataforma y capturas.
- Pruebas en un dispositivo e-ink real.

**Criterio de aceptación:** instalable copiando la carpeta; sin errores en `crash.log`
tras una sesión de uso normal.

**Estimación total:** ≈ 7,5 días de trabajo efectivo.

---

## 10. Estrategia de pruebas

### 10.1 Manual en emulador

Guion de regresión a ejecutar al cerrar cada fase: crear, marcar, editar, eliminar,
filtrar, reiniciar y verificar persistencia; repetir el guion en el gestor de archivos
y dentro de un libro.

### 10.2 Unitarias (`busted`)

`todostore.lua` es Lua puro y se prueba sin interfaz. Casos mínimos:

- `add` asigna ids crecientes y nunca reutilizados.
- `toggle` fija y limpia `completed` de forma consistente con `done`.
- `remove` sobre un id inexistente no lanza error.
- `list` con cada filtro y cada criterio de orden.
- `load` sobre archivo ausente → estado vacío válido.
- `load` sobre archivo corrupto → estado vacío más aviso, sin excepción.
- `load` con `version` menor → migración aplicada; con `version` mayor → solo lectura.

### 10.3 Casos límite a cubrir en la interfaz

- Título vacío o solo espacios → no se crea la tarea.
- Título muy largo → truncado en la lista, completo al editar.
- Lista vacía → mensaje guía en lugar de una pantalla en blanco.
- Libro vinculado borrado del dispositivo.
- Suspensión del dispositivo con un diálogo abierto.

### 10.4 Estático

`luacheck` con la configuración del propio repositorio de KOReader.

---

## 11. Internacionalización

Todas las cadenas visibles pasan por `local _ = require("gettext")`. Para cadenas con
sustitución, `local T = require("ffi/util").template` y `T(_("To-do list (%1)"), n)`.
Nunca concatenar fragmentos traducibles: rompe el orden de las palabras en otros idiomas.
`_meta.lua` también traduce `fullname` y `description`.

---

## 12. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Pérdida de datos por apagado abrupto | Alto | D5: volcado inmediato tras cada mutación |
| Cambios de API entre versiones de KOReader | Medio | Ceñirse a las APIs de §2 (estables y usadas por plugins del núcleo); verificar §2.3 antes de empezar |
| Refrescos de pantalla e-ink excesivos | Medio | Refresco parcial al alternar una tarea; no reconstruir toda la `item_table` cuando cambia una sola fila |
| Rendimiento con listas grandes | Bajo | Filtrado y orden en el store, no en el render; paginación nativa del widget `Menu` |
| Archivo de datos corrupto | Medio | Carga defensiva con `pcall`; copia `.bak` antes de cada volcado |
| Colisión del índice en el diálogo de selección con otro plugin | Bajo | Prefijo numérico poco usado (`12_todolist`) y verificación en el emulador |

---

## 13. Backlog posterior a la v1

1. Exportar e importar en Markdown (`- [ ] tarea`) para interoperar con Obsidian o Logseq.
2. Vista agrupada por libro.
3. Subtareas y tareas recurrentes (requeriría `version = 2` del esquema).
4. Sincronización opcional vía WebDAV reutilizando la infraestructura de red de KOReader.
5. Migración a SQLite si el volumen o la complejidad de los filtros lo justifican.
6. Widget de resumen en la pantalla de inicio del gestor de archivos.

---

## 14. Apéndice — Esqueletos de referencia

### `_meta.lua`

```lua
local _ = require("gettext")
return {
    fullname = _("To-do list"),
    description = _([[Create and manage a to-do list, optionally linked to books and pages.]]),
}
```

### `main.lua` (estructura mínima de la fase 1)

```lua
local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local TodoList = WidgetContainer:extend{
    name = "todolist",
    is_doc_only = false,
}

function TodoList:onDispatcherRegisterActions()
    Dispatcher:registerAction("todolist_show",
        { category = "none", event = "ShowTodoList",
          title = _("To-do list"), general = true })
end

function TodoList:init()
    self:onDispatcherRegisterActions()
    self.store = require("todostore"):open()
    self.ui.menu:registerToMainMenu(self)
    if self.ui.highlight then
        self:registerHighlightButton()
    end
end

function TodoList:addToMainMenu(menu_items)
    menu_items.todo_list = {
        text = _("To-do list"),
        sorting_hint = "more_tools",
        callback = function() self:onShowTodoList() end,
    }
end

function TodoList:onShowTodoList()
    UIManager:show(require("todolistview"):new{ store = self.store })
    return true
end

function TodoList:onFlushSettings()
    if self.store then self.store:flush() end
end

return TodoList
```

---

## 15. Referencias

- [Plugin de ejemplo `hello.koplugin`](https://github.com/koreader/koreader/blob/master/plugins/hello.koplugin/main.lua) — estructura mínima.
- [`profiles.koplugin`](https://github.com/koreader/koreader/blob/master/plugins/profiles.koplugin/main.lua) — `LuaSettings`, `DataStorage`, diálogos y dispatcher dinámico.
- [`vocabbuilder.koplugin`](https://github.com/koreader/koreader/blob/master/plugins/vocabbuilder.koplugin/main.lua) — integración con el lector y almacenamiento propio.
- [`frontend/ui/widget/menu.lua`](https://github.com/koreader/koreader/blob/master/frontend/ui/widget/menu.lua) — API del widget de lista.
- [`frontend/ui/menusorter.lua`](https://github.com/koreader/koreader/blob/master/frontend/ui/menusorter.lua) — semántica de `sorting_hint`.
- [`frontend/apps/reader/modules/readerhighlight.lua`](https://github.com/koreader/koreader/blob/master/frontend/apps/reader/modules/readerhighlight.lua) — `addToHighlightDialog`.
- [Sistema de plugins de KOReader (DeepWiki)](https://deepwiki.com/koreader/koreader/9-plugin-system-and-extensions) — visión general de la carga de plugins.
