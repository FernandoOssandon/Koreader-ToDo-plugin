# Guía de verificación — `todolist.koplugin`

Qué hay que hacer para cerrar las casillas de
[openspec/changes/add-todolist-plugin/tasks.md](openspec/changes/add-todolist-plugin/tasks.md),
y cómo montar el entorno necesario.

---

## 0. Estado de partida

El código está escrito por completo: las seis piezas del plugin, las pruebas
unitarias y la documentación. El **entorno A (ligero)** ya se montó — en un
contenedor Ubuntu 22.04 con Lua 5.1, `busted` y `luacheck`, ya que este
equipo no tiene WSL con una distro Linux instalada — y pasó en verde. El
**entorno B (emulador de KOReader)** sigue sin montar.

Por eso en `tasks.md` están marcadas las tareas 1.3, 3.1–3.4, 7.1, 7.2, 8.2 y
8.3: todas las que se cierran con el entorno ligero, más la 1.3 que se cerró
leyendo el código fuente de KOReader. Las otras 27 casillas siguen abiertas
porque exigen el emulador o un dispositivo real.

| | |
| --- | --- |
| Escrito | `todolist.koplugin/` (6 archivos), `spec/todostore_spec.lua` |
| Verificado | 9 de 36 tareas: 1.3 (lectura de fuentes) + 8 con el entorno ligero |
| Pendiente | 27 casillas, todas en el emulador o en un dispositivo (entorno B) |

Archivos entregados:

```
todolist.koplugin/
├── _meta.lua            -- nombre y descripción para Ajustes → Plugins
├── main.lua             -- ciclo de vida, menú, gestos, selección de texto, salto al libro
├── todostore.lua        -- datos y persistencia, sin dependencias de interfaz
├── todolistview.lua     -- pantalla de lista sobre el widget Menu
├── todoeditdialog.lua   -- alta y edición de una tarea
└── README.md            -- instalación y uso
spec/todostore_spec.lua  -- 34 pruebas unitarias con busted, todas en verde
.luacheckrc              -- configuración del análisis estático, sin avisos
```

---

## 1. Entorno A — pruebas automáticas (ligero)

Cubre 12 de las 35 casillas pendientes. No necesita KOReader: `todostore.lua`
no carga nada de la interfaz y sus dependencias del anfitrión solo se resuelven
cuando no se le inyecta un backend, que es justo lo que hacen las pruebas.

### Instalación en WSL (Ubuntu)

```bash
wsl -d Ubuntu
sudo apt update
sudo apt install -y lua5.1 luarocks
sudo luarocks --lua-version=5.1 install busted
sudo luarocks --lua-version=5.1 install luacheck
```

Usa Lua 5.1 a propósito: KOReader corre sobre LuaJIT, compatible con 5.1. Si
`busted` se instala contra Lua 5.4 las pruebas seguirán pasando, pero dejarán
de representar el intérprete real.

### Ejecución

Desde la raíz del proyecto (`/mnt/c/Proyectos/koreader` dentro de WSL):

```bash
busted spec/todostore_spec.lua     # pruebas unitarias
luacheck todolist.koplugin/        # análisis estático
```

El archivo de pruebas ajusta `package.path` por su cuenta, así que no hacen
falta flags adicionales. Salida esperada: 30 pruebas en verde y `luacheck` sin
avisos.

---

## 2. Entorno B — emulador de KOReader (pesado)

Cubre las 23 casillas restantes. Es una compilación larga: la descarga de
dependencias y el primer `build` tardan fácilmente entre 30 y 60 minutos.

```bash
sudo apt install -y build-essential git cmake autoconf automake libtool \
  pkg-config nasm ragel libsdl2-dev gettext libssl-dev patch wget unzip

git clone https://github.com/koreader/koreader.git
cd koreader
./kodev fetch-thirdparty
./kodev build
./kodev run
```

### Instalar el plugin en el emulador

Dos opciones. La segunda evita recompilar en cada cambio:

1. Copiar `todolist.koplugin/` al directorio `plugins/` del árbol de fuentes
   **antes** de `./kodev build`.
2. Copiar o enlazar la carpeta en el `plugins/` del directorio de ejecución que
   imprime `./kodev run` al arrancar:

```bash
ln -s /mnt/c/Proyectos/koreader/todolist.koplugin \
      <directorio-de-ejecución>/plugins/todolist.koplugin
```

Tras cada cambio en el código hay que reiniciar KOReader; no hay recarga en
caliente. Los errores en tiempo de ejecución aparecen en `crash.log`, en la
raíz del directorio de ejecución.

### Sembrar datos de prueba

Para la tarea 4.5 hace falta un almacén con 200 tareas. Crea el archivo
`todolist.lua` en el directorio de ajustes del emulador con:

```bash
lua5.1 -e '
local t = {}
for i = 1, 200 do
  t[i] = { id = i, title = "Tarea de prueba " .. i, done = i % 4 == 0,
           priority = (i % 3) + 1, created = os.time() - i * 60, notes = "" }
end
local f = io.open("todolist.lua", "w")
f:write("return {\n  version = 1,\n  next_id = 201,\n  tasks = {\n")
for _, x in ipairs(t) do
  f:write(string.format("    { id = %d, title = %q, done = %s, priority = %d, created = %d, notes = \"\" },\n",
          x.id, x.title, tostring(x.done), x.priority, x.created))
end
f:write("  },\n}\n")
f:close()'
```

---

## 3. Qué cierra cada casilla

### Grupo 1 — Preparación

| Tarea | Cómo cerrarla |
| --- | --- |
| 1.1 | Entorno B: `./kodev run` arranca y muestra el gestor de archivos |
| 1.2 | Entorno B: quitar el bloque `if true then return { disabled = true } end` de `plugins/hello.koplugin/main.lua` y comprobar que su entrada aparece |
| 1.3 | **Hecha.** Respuestas anotadas en `design.md`, sección Open Questions |

### Grupo 2 — Esqueleto

| Tarea | Cómo cerrarla |
| --- | --- |
| 2.1 | Entorno B: el plugin aparece en *Ajustes → Plugins* como «To-do list» |
| 2.2 | Entorno B: la entrada sale bajo *Herramientas → Más herramientas*, con el gestor de archivos y con un libro abierto |
| 2.3 | Entorno B: en *Ajustes → Gestos*, asignar «To-do list» a un gesto y ejecutarlo |

### Grupo 3 — Almacén

| Tarea | Cómo cerrarla |
| --- | --- |
| 3.1 | Entorno A: bloques «creación de tareas» y «estado y edición» de `spec/todostore_spec.lua` |
| 3.2 | Entorno A: pruebas de título vacío, normalización multilínea y marca de completado |
| 3.3 | Entorno A: bloque «versionado del esquema» |
| 3.4 | Entorno A: bloque «capa de archivo» (`probeFile` y `backupFile`) |
| 3.5 | Entorno B: crear una tarea, matar el proceso del emulador con `kill -9`, reabrir y comprobar que sigue ahí |

### Grupo 4 — Lista

| Tarea | Cómo cerrarla |
| --- | --- |
| 4.1 | Entorno B: se listan las tareas con su marcador `[ ]` / `[x]`, y las hechas salen atenuadas |
| 4.2 | Entorno B: con la lista vacía aparece el texto guía en lugar de una pantalla en blanco |
| 4.3 | Entorno B: ir a la tercera página, marcar una tarea, comprobar que sigues en esa página con la tarea a la vista |
| 4.4 | Entorno B: crear → marcar → reiniciar KOReader → los estados persisten |
| 4.5 | Entorno B con los datos sembrados: abrir la lista y pasar páginas sin bloqueo perceptible |

### Grupo 5 — Edición y borrado

| Tarea | Cómo cerrarla |
| --- | --- |
| 5.1 | Entorno B: pulsación larga abre el diálogo; «Go to book» sale deshabilitada en una tarea sin vínculo |
| 5.2 | Entorno B: vaciar el título de una tarea e intentar guardar; debe rechazarse con aviso y conservar el anterior |
| 5.3 | Entorno B: cancelar el borrado deja la tarea; confirmarlo elimina solo esa |

### Grupo 6 — Integración con el lector

| Tarea | Cómo cerrarla |
| --- | --- |
| 6.1 | Entorno B: poner fecha pasada a una tarea pendiente (debe salir con `!`), luego «No date» (debe dejar de estarlo) |
| 6.2 | Entorno B: marcar prioridad alta y comprobar que la fila sale en negrita |
| 6.3 | Entorno B: «Go to book» salta a la página; renombrar el archivo del libro y repetir para ver el aviso sin fallo |
| 6.4 | Entorno B: seleccionar varias líneas de un EPUB y usar «Add to to-do list»; el título no debe traer saltos de línea |
| 6.5 | Entorno B: asignar las dos acciones a gestos y comprobar que la segunda previncula libro y página |

### Grupo 7 — Filtros y orden

| Tarea | Cómo cerrarla |
| --- | --- |
| 7.1 | Entorno A: bloque «filtros» |
| 7.2 | Entorno A: bloque «ordenación» |
| 7.3 | Entorno B: el icono de la barra de título abre filtros y orden; el encabezado muestra filtro y recuento |
| 7.4 | Entorno B: cambiar filtro y orden, reiniciar KOReader, comprobar que se mantienen (bloque «persistencia y estado de la vista» del entorno A lo cubre a nivel de datos) |
| 7.5 | Entorno B: abrir la lista desde el gestor de archivos; «This book» sale deshabilitada y no hay error |
| 7.6 | Entorno B: con pendientes, la entrada del menú muestra el número; al completarlas todas, desaparece |

### Grupo 8 — Pulido

| Tarea | Cómo cerrarla |
| --- | --- |
| 8.1 | Revisión: `grep -n '"' todolist.koplugin/*.lua` y comprobar que toda cadena visible va dentro de `_()` o `T(_())` |
| 8.2 | Entorno A: `luacheck todolist.koplugin/` sin avisos |
| 8.3 | Entorno A: `busted spec/todostore_spec.lua` en verde |
| 8.4 | Que alguien ajeno instale el plugin siguiendo solo `todolist.koplugin/README.md` |
| 8.5 | Guion de regresión (§5) en un dispositivo e-ink real, revisando `crash.log` al terminar |
| 8.6 | Entorno B: desactivar el plugin, reiniciar, comprobar que no queda rastro; reactivar y ver que las tareas siguen |

---

## 4. Puntos de riesgo: qué mirar primero

Estas son las llamadas a la API de KOReader que no se pudieron ejecutar. Si algo
falla al arrancar el plugin, es casi seguro que está aquí. Conviene comprobarlas
en este orden, antes del guion completo.

1. **Resolución de módulos hermanos.** `main.lua` hace `require("todostore")`,
   `require("todolistview")` y `require("todoeditdialog")` confiando en que el
   cargador de plugins añade el directorio del plugin a `package.path`. Es la
   convención que siguen los plugins del núcleo, pero es lo primero que rompe si
   no se cumple: el plugin no cargaría en absoluto.
2. **`DateTimeWidget` con `extra_text` / `extra_callback`.** Se usa el botón
   extra para «sin fecha». Está confirmado que el widget se cierra solo tras
   pulsar OK, pero no qué hace tras el botón extra. En
   `todoeditdialog.lua:editDue` el callback llama a `UIManager:close(picker)`;
   si el widget ya se cierra por su cuenta, hay que quitar esa llamada.
3. **`Menu:updateItems(idx)`.** Es lo que permite alternar una tarea sin
   reconstruir la lista (tarea 4.3). Si el cambio de `dim` o `bold` no se
   refleja, sustituir la llamada por `refreshList(idx)` en
   `todolistview.lua:refreshItem`, aceptando un refresco mayor.
4. **`sorting_hint = "more_tools"`.** Si la entrada aparece en el primer menú
   con el prefijo `"NEW: "`, el identificador no se reconoció en esa versión.
5. **`util.cleanupSelectedText`.** Usada en `main.lua:registerHighlightButton`.
   Si no existe en la versión objetivo, basta con `TodoStore.normalizeTitle`,
   que ya hace la normalización exigida por la especificación.
6. **`ui.doc_props.display_title`.** En `getBookContext`. Si es nil, el título
   cae al nombre de archivo mediante `ffiUtil.basename`; comprobar que el
   fallback se activa y no deja el título vacío.
7. **`Event:new("GotoPage", page)`.** Debe funcionar tanto en documentos
   paginados (PDF) como reflowables (EPUB). Probar con los dos formatos.
8. **Salto a un libro distinto del abierto.** `goToBook` guarda el destino en
   `TodoList.pending_jump` y lo completa en `onReaderReady`. Verificar que ese
   evento llega al plugin y que el salto ocurre después de restaurar la última
   posición, no antes.
9. **Almacén compartido entre interfaces.** El almacén cuelga de la clase
   (`TodoList.store`), no de la instancia, porque KOReader crea un plugin por
   interfaz. Comprobar que una tarea creada en el lector aparece al volver al
   gestor de archivos sin reiniciar.

---

## 5. Guion de regresión manual

Recorrido completo, una vez en el gestor de archivos y otra con un libro
abierto. Es el guion de las tareas 8.5 y 8.6.

1. Abrir la lista desde *Herramientas → Más herramientas*.
2. Crear tres tareas desde `+ New task`.
3. Marcar una como hecha; comprobar que se atenúa y que el recuento del menú baja.
4. Volver a marcarla como pendiente.
5. Pulsación larga → editar título; guardar y ver el cambio.
6. Pulsación larga → notas; guardar y reabrir para comprobar que se conservan.
7. Pulsación larga → fecha límite en el pasado; comprobar la marca `!`.
8. Pulsación larga → fecha límite → «No date»; comprobar que se quita.
9. Pulsación larga → prioridad alta; comprobar la negrita.
10. Probar los cinco filtros y los cuatro criterios de orden.
11. Eliminar una tarea cancelando primero y confirmando después.
12. Con un libro abierto: seleccionar texto y crear una tarea desde la selección.
13. Cerrar el libro, abrir la lista y usar «Go to book» en esa tarea.
14. Renombrar el archivo del libro fuera de KOReader y repetir el paso 13:
    debe avisar sin fallar.
15. Reiniciar KOReader y comprobar que todo sigue como se dejó, incluidos el
    filtro y el orden activos.
16. Revisar `crash.log`.

---

## 6. Cuando todo esté verificado

Marcar las casillas en `tasks.md` y archivar el cambio, que traslada las specs
delta a `openspec/specs/`:

```bash
openspec status --change add-todolist-plugin
openspec archive add-todolist-plugin
```
