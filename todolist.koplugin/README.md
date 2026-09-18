# To-do list — plugin para KOReader

Anota tareas sin salir del lector. Una tarea puede quedar vinculada al libro y
la página en que la creaste, de modo que después puedes volver al punto exacto
del texto que la originó.

## Instalación

Copia la carpeta `todolist.koplugin` completa al directorio de plugins de
KOReader y reinicia la aplicación:

| Plataforma | Ruta |
| --- | --- |
| Kobo / Kindle | `koreader/plugins/` |
| Android | `/sdcard/koreader/plugins/` |
| Linux | `~/.config/koreader/plugins/` |

Si tienes configurado el ajuste `extra_plugin_paths`, también se busca ahí.

No hay que modificar ningún archivo de KOReader. El plugin se puede desactivar
desde *Ajustes → Plugins*; al hacerlo las tareas guardadas se conservan.

## Uso

La lista se abre desde *Herramientas → Más herramientas → To-do list*. La
entrada muestra entre paréntesis cuántas tareas pendientes tienes.

Dentro de la lista:

| Gesto | Qué hace |
| --- | --- |
| Toque en una tarea | Alterna entre pendiente y hecha |
| Pulsación larga | Editar, fecha límite, prioridad, ir al libro, eliminar |
| Icono de la barra de título | Filtros y ordenación |
| Fila `+ New task` | Crear una tarea |

Una tarea recién marcada no desaparece de la lista aunque deje de cumplir el
filtro activo: así un toque accidental se puede deshacer en el acto. Se
recoloca en el siguiente refresco completo.

### Mientras lees

- Selecciona texto y elige **Add to to-do list**: se crea una tarea con ese
  texto como título, vinculada al libro y la página.
- En *Ajustes → Gestos* puedes asignar tres acciones: abrir la lista, crear una
  tarea rápida y crear una tarea vinculada al libro actual.

### Fechas límite

Una tarea con fecha límite vence al terminar el día indicado, no al empezarlo.
Las vencidas se marcan con `!` junto a la fecha. Una tarea sin fecha no vence
nunca, y una tarea ya hecha tampoco.

## Dónde se guardan las tareas

En un único archivo en el directorio de ajustes de KOReader:

```
<ajustes de KOReader>/todolist.lua
```

Es un archivo Lua legible que puedes respaldar o inspeccionar. El plugin no
escribe en los ajustes generales ni en los datos de ningún libro. Antes de cada
escritura conserva una copia en `todolist.lua.bak`.

Si el archivo se corrompe, el plugin arranca con una lista vacía, guarda el
original en `.bak` y te avisa. Si lo escribió una versión más nueva del plugin,
se abre en modo solo lectura para no dañar los datos.

## Licencia

Distribuido bajo los mismos términos que KOReader.
