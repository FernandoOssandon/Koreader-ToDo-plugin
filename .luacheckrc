-- Configuración de luacheck para el plugin y sus pruebas.
-- KOReader corre sobre LuaJIT, compatible con Lua 5.1.

std = "luajit"

-- Como en el propio repositorio de KOReader: la longitud de línea no se limita.
max_line_length = false

-- Globales que expone KOReader a los plugins.
read_globals = {
    "G_reader_settings",
}

-- KOReader invoca los manejadores de evento como métodos (dos puntos) y
-- siempre pasa `self`, aunque el manejador no lo necesite: no es código
-- muerto, es la convención de despacho del anfitrión.
ignore = { "212/self" }

files["spec/"] = {
    std = "+busted",
}
