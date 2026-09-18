--[[--
Pruebas unitarias del almacén de tareas.

Se ejecutan con `busted` y Lua a secas, sin KOReader: `todostore.lua` no carga
nada de la interfaz y sus dependencias del anfitrión solo se resuelven cuando
no se inyecta un backend.

    busted spec/todostore_spec.lua

--]]--

package.path = "todolist.koplugin/?.lua;" .. package.path

local TodoStore = require("todostore")

-- Backend en memoria con la misma interfaz que LuaSettings.
local function FakeBackend(initial)
    local backend = { data = initial or {}, flush_count = 0 }
    function backend:readSetting(key, default)
        local value = self.data[key]
        if value == nil then return default end
        return value
    end
    function backend:saveSetting(key, value) self.data[key] = value end
    function backend:flush() self.flush_count = self.flush_count + 1 end
    return backend
end

local NOW = 1758067200 -- 2025-09-17 00:00:00 UTC
local DAY = 86400

local function openStore(initial, now)
    return TodoStore:open({
        backend = FakeBackend(initial),
        now = function() return now or NOW end,
    })
end

local function titlesOf(tasks)
    local out = {}
    for i, task in ipairs(tasks) do out[i] = task.title end
    return out
end

describe("TodoStore: creación de tareas", function()
    it("crea una tarea pendiente con los valores por defecto", function()
        local store = openStore()
        local task = store:add({ title = "Revisar la cita del capítulo 3" })

        assert.is_table(task)
        assert.is_false(task.done)
        assert.are.equal(TodoStore.PRIORITY.NORMAL, task.priority)
        assert.are.equal(NOW, task.created)
        assert.is_nil(task.due)
        assert.is_nil(task.completed)
    end)

    it("rechaza un título vacío o compuesto solo por espacios", function()
        local store = openStore()

        local task, err = store:add({ title = "" })
        assert.is_nil(task)
        assert.are.equal(TodoStore.ERR_EMPTY_TITLE, err)

        task, err = store:add({ title = "   \n\t  " })
        assert.is_nil(task)
        assert.are.equal(TodoStore.ERR_EMPTY_TITLE, err)
        assert.are.equal(0, #store.tasks)
    end)

    it("normaliza títulos multilínea a una sola línea sin espacios duplicados", function()
        local store = openStore()
        local task = store:add({ title = "  una cita\n   partida  en   líneas \n" })
        assert.are.equal("una cita partida en líneas", task.title)
    end)

    it("asigna identificadores crecientes que no se reutilizan tras un borrado", function()
        local store = openStore()
        local first = store:add({ title = "primera" })
        local second = store:add({ title = "segunda" })
        assert.is_true(second.id > first.id)

        store:remove(second.id)
        local third = store:add({ title = "tercera" })
        assert.are_not.equal(second.id, third.id)
        assert.is_true(third.id > second.id)
    end)
end)

describe("TodoStore: estado y edición", function()
    it("fija y limpia la marca de completado al alternar el estado", function()
        local store = openStore()
        local task = store:add({ title = "tarea" })

        store:toggle(task.id)
        assert.is_true(task.done)
        assert.are.equal(NOW, task.completed)

        store:toggle(task.id)
        assert.is_false(task.done)
        assert.is_nil(task.completed)
    end)

    it("rechaza una edición que dejaría el título vacío y conserva el anterior", function()
        local store = openStore()
        local task = store:add({ title = "título original" })

        local updated, err = store:update(task.id, { title = "   " })
        assert.is_nil(updated)
        assert.are.equal(TodoStore.ERR_EMPTY_TITLE, err)
        assert.are.equal("título original", store:get(task.id).title)
    end)

    it("limpia la fecha límite cuando se pasa due = false", function()
        local store = openStore()
        local task = store:add({ title = "tarea", due = NOW + DAY })
        assert.are.equal(NOW + DAY, task.due)

        store:update(task.id, { due = false })
        assert.is_nil(store:get(task.id).due)
    end)

    it("no falla al eliminar un identificador inexistente", function()
        local store = openStore()
        local ok, err = store:remove(4242)
        assert.is_nil(ok)
        assert.are.equal(TodoStore.ERR_NOT_FOUND, err)
    end)

    it("elimina solo la tarea indicada", function()
        local store = openStore()
        local keep = store:add({ title = "se queda" })
        local drop = store:add({ title = "se va" })

        store:remove(drop.id)
        assert.are.equal(1, #store.tasks)
        assert.are.equal(keep.id, store.tasks[1].id)
    end)
end)

describe("TodoStore: vencimiento", function()
    it("considera vencida una tarea pendiente con plazo pasado", function()
        local store = openStore()
        local task = store:add({ title = "tarea", due = NOW - DAY })
        assert.is_true(store:isOverdue(task))
    end)

    it("no considera vencida una tarea hecha con plazo pasado", function()
        local store = openStore()
        local task = store:add({ title = "tarea", due = NOW - DAY })
        store:toggle(task.id)
        assert.is_false(store:isOverdue(task))
    end)

    it("no considera vencida nunca una tarea sin plazo", function()
        local store = openStore()
        local task = store:add({ title = "tarea" })
        assert.is_false(store:isOverdue(task))
        assert.is_false(store:isOverdue(task, NOW + 100 * DAY))
    end)
end)

describe("TodoStore: filtros", function()
    local function seed()
        local store = openStore()
        store:add({ title = "pendiente" })
        local done = store:add({ title = "hecha" })
        store:toggle(done.id)
        store:add({ title = "vencida", due = NOW - DAY })
        store:add({ title = "del libro", book = { path = "/libros/rosa.epub" } })
        return store
    end

    it("devuelve todas las tareas con el filtro all", function()
        assert.are.equal(4, #seed():list({ filter = "all" }))
    end)

    it("devuelve solo las pendientes con el filtro pending", function()
        local tasks = seed():list({ filter = "pending" })
        assert.are.equal(3, #tasks)
        for _, task in ipairs(tasks) do assert.is_false(task.done) end
    end)

    it("devuelve solo las hechas con el filtro done", function()
        local tasks = seed():list({ filter = "done" })
        assert.are.same({ "hecha" }, titlesOf(tasks))
    end)

    it("devuelve solo las vencidas con el filtro overdue", function()
        local tasks = seed():list({ filter = "overdue" })
        assert.are.same({ "vencida" }, titlesOf(tasks))
    end)

    it("devuelve solo las del libro indicado con el filtro book", function()
        local tasks = seed():list({ filter = "book", book_path = "/libros/rosa.epub" })
        assert.are.same({ "del libro" }, titlesOf(tasks))
    end)

    it("no devuelve nada con el filtro book si no hay libro de referencia", function()
        assert.are.equal(0, #seed():list({ filter = "book" }))
    end)
end)

describe("TodoStore: ordenación", function()
    local function seed()
        local store = openStore()
        store:add({ title = "beta",  created = NOW + 2, priority = TodoStore.PRIORITY.LOW,    due = NOW + 2 * DAY })
        store:add({ title = "alfa",  created = NOW + 3, priority = TodoStore.PRIORITY.HIGH })
        store:add({ title = "gamma", created = NOW + 1, priority = TodoStore.PRIORITY.NORMAL, due = NOW + DAY })
        return store
    end

    it("ordena por fecha de creación, de la más antigua a la más reciente", function()
        assert.are.same({ "gamma", "beta", "alfa" },
                        titlesOf(seed():list({ filter = "all", sort = "created" })))
    end)

    it("ordena por fecha límite y agrupa al final las tareas sin plazo", function()
        assert.are.same({ "gamma", "beta", "alfa" },
                        titlesOf(seed():list({ filter = "all", sort = "due" })))
    end)

    it("ordena por prioridad, de la más alta a la más baja", function()
        assert.are.same({ "alfa", "gamma", "beta" },
                        titlesOf(seed():list({ filter = "all", sort = "priority" })))
    end)

    it("ordena alfabéticamente por título", function()
        assert.are.same({ "alfa", "beta", "gamma" },
                        titlesOf(seed():list({ filter = "all", sort = "title" })))
    end)
end)

describe("TodoStore: recuentos", function()
    it("cuenta el total, las pendientes, las hechas y las vencidas", function()
        local store = openStore()
        store:add({ title = "pendiente" })
        store:add({ title = "vencida", due = NOW - DAY })
        local done = store:add({ title = "hecha" })
        store:toggle(done.id)

        local counts = store:counts()
        assert.are.equal(3, counts.total)
        assert.are.equal(2, counts.pending)
        assert.are.equal(1, counts.done)
        assert.are.equal(1, counts.overdue)
    end)
end)

describe("TodoStore: persistencia y estado de la vista", function()
    it("escribe en el backend tras cada mutación, sin esperar al cierre", function()
        local backend = FakeBackend()
        local store = TodoStore:open({ backend = backend, now = function() return NOW end })

        store:add({ title = "tarea" })
        assert.is_true(backend.flush_count >= 1)
        assert.are.equal(1, #backend.data.tasks)
    end)

    it("conserva el filtro y el orden elegidos", function()
        local backend = FakeBackend()
        local store = TodoStore:open({ backend = backend, now = function() return NOW end })
        store:setView("overdue", "priority")

        local reopened = TodoStore:open({ backend = backend, now = function() return NOW end })
        assert.are.equal("overdue", reopened.view.filter)
        assert.are.equal("priority", reopened.view.sort)
    end)

    it("ignora un filtro o un orden desconocidos guardados en el archivo", function()
        local store = openStore({ view = { filter = "inventado", sort = "raro" }, tasks = {} })
        assert.are.equal(TodoStore.DEFAULT_VIEW.filter, store.view.filter)
        assert.are.equal(TodoStore.DEFAULT_VIEW.sort, store.view.sort)
    end)
end)

describe("TodoStore: versionado del esquema", function()
    it("trata un almacén nuevo como ya actualizado", function()
        local store = openStore()
        assert.are.equal(TodoStore.SCHEMA_VERSION, store.version)
        assert.is_false(store.was_migrated)
        assert.is_false(store:isReadOnly())
    end)

    it("migra un almacén anterior al versionado", function()
        local store = openStore({
            tasks = {
                { id = 1, title = "  antigua  ", done = false },
                { id = 4, title = "otra", done = true },
            },
        })

        assert.are.equal(TodoStore.SCHEMA_VERSION, store.version)
        assert.is_true(store.was_migrated)
        assert.are.equal("antigua", store:get(1).title)
        assert.are.equal(TodoStore.DEFAULT_PRIORITY, store:get(1).priority)
        -- next_id debe quedar por encima del mayor identificador existente.
        assert.is_true(store.next_id > 4)
    end)

    it("abre en solo lectura un almacén de una versión posterior", function()
        local store = openStore({
            version = TodoStore.SCHEMA_VERSION + 1,
            tasks = { { id = 1, title = "futura", done = false, priority = 2, created = NOW } },
            next_id = 2,
        })

        assert.is_true(store:isReadOnly())
        assert.are.equal(1, #store:list({ filter = "all" }))

        local task, err = store:add({ title = "nueva" })
        assert.is_nil(task)
        assert.are.equal(TodoStore.ERR_READ_ONLY, err)

        local ok, toggle_err = store:toggle(1)
        assert.is_nil(ok)
        assert.are.equal(TodoStore.ERR_READ_ONLY, toggle_err)
    end)
end)

describe("TodoStore: capa de archivo", function()
    local function writeFile(path, content)
        local handle = assert(io.open(path, "w"))
        handle:write(content)
        handle:close()
    end

    it("clasifica como missing un archivo que no existe", function()
        assert.are.equal("missing", TodoStore.probeFile("/no/existe/todolist.lua"))
    end)

    it("clasifica como corrupt un archivo ilegible", function()
        local path = os.tmpname()
        writeFile(path, "esto no es Lua válido {{{")
        assert.are.equal("corrupt", TodoStore.probeFile(path))
        os.remove(path)
    end)

    it("clasifica como corrupt un archivo que no devuelve una tabla", function()
        local path = os.tmpname()
        writeFile(path, "return 42")
        assert.are.equal("corrupt", TodoStore.probeFile(path))
        os.remove(path)
    end)

    it("clasifica como ok un archivo válido y devuelve sus datos", function()
        local path = os.tmpname()
        writeFile(path, "return { version = 1, tasks = {} }")
        local state, data = TodoStore.probeFile(path)
        assert.are.equal("ok", state)
        assert.are.equal(1, data.version)
        os.remove(path)
    end)

    it("conserva una copia .bak del archivo original", function()
        local path = os.tmpname()
        writeFile(path, "return { version = 1 }")

        assert.is_true(TodoStore.backupFile(path))
        local state, data = TodoStore.probeFile(path .. ".bak")
        assert.are.equal("ok", state)
        assert.are.equal(1, data.version)

        os.remove(path)
        os.remove(path .. ".bak")
    end)
end)
