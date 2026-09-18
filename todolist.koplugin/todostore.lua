--[[--
Almacén de tareas de la lista de pendientes.

Este módulo no depende de la interfaz: no carga nada bajo `ui/widget/`. Las
dependencias de KOReader (`luasettings`, `datastorage`) se cargan de forma
perezosa y solo cuando no se inyecta un backend, de modo que las pruebas
unitarias puedan ejecutarse con Lua a secas.

Un backend es cualquier objeto con `readSetting(key, default)`,
`saveSetting(key, value)` y `flush()`; `LuaSettings` cumple esa interfaz.

@module todolist.todostore
--]]--

local TodoStore = {}
TodoStore.__index = TodoStore

--- Versión del esquema en disco. Incrementarla obliga a añadir su migración.
TodoStore.SCHEMA_VERSION = 1

TodoStore.DEFAULT_FILENAME = "todolist.lua"

TodoStore.PRIORITY = { HIGH = 1, NORMAL = 2, LOW = 3 }
TodoStore.DEFAULT_PRIORITY = TodoStore.PRIORITY.NORMAL

TodoStore.FILTERS = { "all", "pending", "done", "overdue", "book" }
TodoStore.SORTS = { "created", "due", "priority", "title" }

TodoStore.DEFAULT_VIEW = { filter = "pending", sort = "created" }

-- Errores devueltos como segundo valor por los mutadores.
TodoStore.ERR_EMPTY_TITLE = "empty_title"
TodoStore.ERR_READ_ONLY = "read_only"
TodoStore.ERR_NOT_FOUND = "not_found"

------------------------------------------------------------------------------
-- Ayudas internas
------------------------------------------------------------------------------

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

--- Recorta los extremos y colapsa cualquier secuencia de espacios o saltos de
--- línea en un único espacio. Es lo que garantiza que un título creado desde
--- una selección multilínea no arrastre saltos ni espacios duplicados.
local function normalizeTitle(title)
    if type(title) ~= "string" then return "" end
    local collapsed = title:gsub("%s+", " ")
    return collapsed:match("^%s*(.-)%s*$") or ""
end
TodoStore.normalizeTitle = normalizeTitle

--- Comparación alfabética. Dentro de KOReader usa la intercalación de la
--- locale; fuera de él cae a una comparación en minúsculas. La resolución se
--- memoiza porque el comparador se invoca una vez por par al ordenar.
local strcoll
local function collate(a, b)
    if strcoll == nil then
        local ok, ffiUtil = pcall(require, "ffi/util")
        strcoll = (ok and ffiUtil and ffiUtil.strcoll) or false
    end
    if strcoll then return strcoll(a, b) end
    return a:lower() < b:lower()
end

------------------------------------------------------------------------------
-- Capa de archivo (Lua puro: verificable sin KOReader)
------------------------------------------------------------------------------

--- Clasifica el archivo del almacén antes de entregárselo a LuaSettings.
--- @return string "missing", "corrupt" u "ok"
--- @return table|nil los datos cuando el resultado es "ok"
function TodoStore.probeFile(path)
    if not path then return "missing" end
    local handle = io.open(path, "r")
    if not handle then return "missing" end
    handle:close()
    local chunk = loadfile(path)
    if not chunk then return "corrupt" end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return "corrupt" end
    return "ok", result
end

--- Copia `path` a `path .. ".bak"`. Devuelve true si la copia se escribió.
function TodoStore.backupFile(path)
    if not path then return false end
    local source = io.open(path, "rb")
    if not source then return false end
    local content = source:read("*a")
    source:close()
    local target = io.open(path .. ".bak", "wb")
    if not target then return false end
    target:write(content)
    target:close()
    return true
end

------------------------------------------------------------------------------
-- Migraciones
------------------------------------------------------------------------------

--- `migrations[n]` lleva los datos de la versión `n` a la `n + 1`.
--- La versión 0 representa un archivo escrito antes de que existiera el campo
--- `version`; su migración se limita a rellenar los campos obligatorios.
TodoStore.migrations = {
    [0] = function(data)
        data.tasks = data.tasks or {}
        local max_id = 0
        for _, task in ipairs(data.tasks) do
            task.id = task.id or (max_id + 1)
            task.title = normalizeTitle(task.title)
            task.done = task.done and true or false
            task.priority = task.priority or TodoStore.DEFAULT_PRIORITY
            task.created = task.created or 0
            task.notes = task.notes or ""
            if task.id > max_id then max_id = task.id end
        end
        data.next_id = math.max(data.next_id or 1, max_id + 1)
        return data
    end,
}

------------------------------------------------------------------------------
-- Apertura
------------------------------------------------------------------------------

--- Abre el almacén.
--- @param opts table|nil
---   `backend`: objeto de ajustes inyectado (las pruebas lo usan).
---   `path`: ruta del archivo; por defecto, el directorio de ajustes de KOReader.
---   `now`: función que devuelve el epoch actual; por defecto `os.time`.
function TodoStore:open(opts)
    opts = opts or {}

    local store = setmetatable({}, TodoStore)
    store.now_fn = opts.now or os.time
    store.path = opts.path
    store.read_only = false
    store.was_corrupt = false
    store.was_migrated = false
    store.dirty = false

    local backend = opts.backend
    if not backend then
        local DataStorage = require("datastorage")
        local LuaSettings = require("luasettings")
        store.path = store.path
            or (DataStorage:getSettingsDir() .. "/" .. TodoStore.DEFAULT_FILENAME)

        -- Carga defensiva: si el archivo existe pero no se puede interpretar,
        -- se conserva una copia y se arranca con una lista vacía.
        local state = TodoStore.probeFile(store.path)
        if state == "corrupt" then
            TodoStore.backupFile(store.path)
            os.remove(store.path)
            store.was_corrupt = true
        end
        backend = LuaSettings:open(store.path)
    end
    store.backend = backend

    store:loadFromBackend()
    return store
end

function TodoStore:loadFromBackend()
    local backend = self.backend
    local version = backend:readSetting("version")
    local tasks = backend:readSetting("tasks")
    local next_id = backend:readSetting("next_id")

    if version == nil and tasks == nil and next_id == nil then
        -- Almacén nuevo: no hay nada que migrar.
        version = TodoStore.SCHEMA_VERSION
    elseif version == nil then
        version = 0
    end

    local data = {
        version = version,
        tasks = tasks or {},
        next_id = next_id or 1,
        view = backend:readSetting("view") or {},
    }

    if data.version > TodoStore.SCHEMA_VERSION then
        -- Datos escritos por una versión posterior del plugin: se muestran,
        -- pero no se tocan.
        self.read_only = true
    elseif data.version < TodoStore.SCHEMA_VERSION then
        while data.version < TodoStore.SCHEMA_VERSION do
            local migrate = TodoStore.migrations[data.version]
            if not migrate then break end
            data = migrate(data) or data
            data.version = data.version + 1
        end
        self.was_migrated = true
    end

    self.version = data.version
    self.tasks = data.tasks
    self.next_id = data.next_id
    self.view = {
        filter = contains(TodoStore.FILTERS, data.view.filter)
            and data.view.filter or TodoStore.DEFAULT_VIEW.filter,
        sort = contains(TodoStore.SORTS, data.view.sort)
            and data.view.sort or TodoStore.DEFAULT_VIEW.sort,
    }

    if self.was_migrated and not self.read_only then
        self:persist()
    end
end

------------------------------------------------------------------------------
-- Persistencia
------------------------------------------------------------------------------

--- Vuelca el estado en memoria al backend y lo escribe en disco.
--- Se llama tras cada mutación: en un e-reader no hay cierre ordenado garantizado.
function TodoStore:persist()
    if self.read_only then return false, TodoStore.ERR_READ_ONLY end
    local backend = self.backend
    backend:saveSetting("version", self.version)
    backend:saveSetting("next_id", self.next_id)
    backend:saveSetting("tasks", self.tasks)
    backend:saveSetting("view", self.view)
    if self.path then
        TodoStore.backupFile(self.path)
    end
    backend:flush()
    self.dirty = false
    return true
end

--- Red de seguridad para `onFlushSettings`: solo escribe si quedó algo pendiente.
function TodoStore:flush()
    if self.dirty then
        return self:persist()
    end
    return true
end

function TodoStore:isReadOnly()
    return self.read_only
end

function TodoStore:now()
    return self.now_fn()
end

------------------------------------------------------------------------------
-- Consulta
------------------------------------------------------------------------------

function TodoStore:get(id)
    for _, task in ipairs(self.tasks) do
        if task.id == id then return task end
    end
    return nil
end

local function indexOf(tasks, id)
    for i, task in ipairs(tasks) do
        if task.id == id then return i end
    end
    return nil
end

--- Una tarea está vencida solo si está pendiente y su plazo ya pasó.
--- Una tarea sin plazo no vence nunca.
function TodoStore:isOverdue(task, now)
    if not task or task.done or not task.due then return false end
    return task.due < (now or self:now())
end

function TodoStore:counts(now)
    now = now or self:now()
    local result = { total = 0, pending = 0, done = 0, overdue = 0 }
    for _, task in ipairs(self.tasks) do
        result.total = result.total + 1
        if task.done then
            result.done = result.done + 1
        else
            result.pending = result.pending + 1
            if self:isOverdue(task, now) then
                result.overdue = result.overdue + 1
            end
        end
    end
    return result
end

function TodoStore:matchesFilter(task, filter, now, book_path)
    if filter == "pending" then return not task.done end
    if filter == "done" then return task.done end
    if filter == "overdue" then return self:isOverdue(task, now) end
    if filter == "book" then
        return book_path ~= nil and task.book ~= nil and task.book.path == book_path
    end
    return true
end

--- Todos los criterios desempatan por identificador, para que la ordenación
--- sea determinista: `table.sort` no es estable.
local function comparatorFor(sort)
    if sort == "due" then
        -- Las tareas sin plazo se agrupan al final.
        return function(a, b)
            if (a.due == nil) ~= (b.due == nil) then return b.due == nil end
            if a.due ~= b.due and a.due and b.due then return a.due < b.due end
            return a.id < b.id
        end
    end
    if sort == "priority" then
        return function(a, b)
            if a.priority ~= b.priority then return a.priority < b.priority end
            if (a.due == nil) ~= (b.due == nil) then return b.due == nil end
            if a.due and b.due and a.due ~= b.due then return a.due < b.due end
            return a.id < b.id
        end
    end
    if sort == "title" then
        return function(a, b)
            if a.title ~= b.title then return collate(a.title, b.title) end
            return a.id < b.id
        end
    end
    -- "created": orden de alta, del más antiguo al más reciente.
    return function(a, b)
        if a.created ~= b.created then return a.created < b.created end
        return a.id < b.id
    end
end

--- Devuelve las tareas que pasan el filtro, ordenadas por el criterio pedido.
--- @param opts table|nil `filter`, `sort`, `book_path`, `now`.
function TodoStore:list(opts)
    opts = opts or {}
    local filter = opts.filter or self.view.filter
    local sort = opts.sort or self.view.sort
    local now = opts.now or self:now()

    local result = {}
    for _, task in ipairs(self.tasks) do
        if self:matchesFilter(task, filter, now, opts.book_path) then
            result[#result + 1] = task
        end
    end
    table.sort(result, comparatorFor(sort))
    return result
end

------------------------------------------------------------------------------
-- Mutación
------------------------------------------------------------------------------

--- Crea una tarea. El título es obligatorio y se normaliza.
--- @return table|nil la tarea creada, o nil y el código de error.
function TodoStore:add(fields)
    if self.read_only then return nil, TodoStore.ERR_READ_ONLY end
    fields = fields or {}

    local title = normalizeTitle(fields.title)
    if title == "" then return nil, TodoStore.ERR_EMPTY_TITLE end

    local task = {
        id = self.next_id,
        title = title,
        done = false,
        priority = fields.priority or TodoStore.DEFAULT_PRIORITY,
        created = fields.created or self:now(),
        due = fields.due,
        completed = nil,
        notes = fields.notes or "",
        book = fields.book,
    }

    -- Los identificadores nunca se reutilizan: next_id solo crece.
    self.next_id = self.next_id + 1
    self.tasks[#self.tasks + 1] = task
    self.dirty = true
    self:persist()
    return task
end

--- Modifica los campos indicados de una tarea existente.
--- Un título que quedara vacío se rechaza y la tarea conserva el anterior.
function TodoStore:update(id, fields)
    if self.read_only then return nil, TodoStore.ERR_READ_ONLY end
    local task = self:get(id)
    if not task then return nil, TodoStore.ERR_NOT_FOUND end

    if fields.title ~= nil then
        local title = normalizeTitle(fields.title)
        if title == "" then return nil, TodoStore.ERR_EMPTY_TITLE end
        task.title = title
    end
    if fields.notes ~= nil then task.notes = fields.notes end
    if fields.priority ~= nil then task.priority = fields.priority end
    if fields.due ~= nil then
        -- `false` limpia el plazo; un número lo fija.
        task.due = fields.due ~= false and fields.due or nil
    end
    if fields.book ~= nil then
        task.book = fields.book ~= false and fields.book or nil
    end

    self.dirty = true
    self:persist()
    return task
end

--- Alterna entre pendiente y hecha, manteniendo coherente la marca `completed`.
function TodoStore:toggle(id)
    if self.read_only then return nil, TodoStore.ERR_READ_ONLY end
    local task = self:get(id)
    if not task then return nil, TodoStore.ERR_NOT_FOUND end

    task.done = not task.done
    task.completed = task.done and self:now() or nil

    self.dirty = true
    self:persist()
    return task
end

--- Elimina una tarea. Eliminar un identificador inexistente no es un error fatal.
function TodoStore:remove(id)
    if self.read_only then return nil, TodoStore.ERR_READ_ONLY end
    local index = indexOf(self.tasks, id)
    if not index then return nil, TodoStore.ERR_NOT_FOUND end

    table.remove(self.tasks, index)
    self.dirty = true
    self:persist()
    return true
end

--- Guarda el filtro y el orden activos para que sobrevivan al reinicio.
function TodoStore:setView(filter, sort)
    if filter and contains(TodoStore.FILTERS, filter) then
        self.view.filter = filter
    end
    if sort and contains(TodoStore.SORTS, sort) then
        self.view.sort = sort
    end
    if not self.read_only then
        self.dirty = true
        self:persist()
    end
    return self.view
end

return TodoStore
