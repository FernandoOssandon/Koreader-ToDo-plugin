-- Configuración de luacheck para el plugin y sus pruebas.
-- KOReader corre sobre LuaJIT, compatible con Lua 5.1.

std = "luajit"

-- Como en el propio repositorio de KOReader: la longitud de línea no se limita.
max_line_length = false

-- Globales que expone KOReader a los plugins.
read_globals = {
    "G_reader_settings",
}

files["spec/"] = {
    std = "+busted",
}
