--[[--
Diálogos de alta y edición de una tarea.

Todas las funciones reciben el almacén, actúan sobre él y avisan mediante
`on_done` para que la vista se refresque. Ninguna escribe en disco por su
cuenta: esa responsabilidad es exclusiva del almacén.

@module todolist.todoeditdialog
--]]--

local ButtonDialog = require("ui/widget/buttondialog")
local DateTimeWidget = require("ui/widget/datetimewidget")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local TodoStore = require("todostore")
local _ = require("gettext")

local TodoEditDialog = {}

local ERROR_TEXT = {
    [TodoStore.ERR_EMPTY_TITLE] = _("The title cannot be empty."),
    [TodoStore.ERR_READ_ONLY] = _("This to-do list was written by a newer version of the plugin, so it cannot be modified."),
    [TodoStore.ERR_NOT_FOUND] = _("That task no longer exists."),
}

local PRIORITY_TEXT = {
    [TodoStore.PRIORITY.HIGH] = _("High"),
    [TodoStore.PRIORITY.NORMAL] = _("Normal"),
    [TodoStore.PRIORITY.LOW] = _("Low"),
}
TodoEditDialog.PRIORITY_TEXT = PRIORITY_TEXT

--- Muestra el motivo por el que el almacén rechazó una operación.
function TodoEditDialog.showError(err)
    UIManager:show(InfoMessage:new{
        text = ERROR_TEXT[err] or _("The task could not be saved."),
    })
end

--- El plazo se guarda al final del día elegido, de modo que una tarea no se
--- considere vencida durante la propia jornada de su fecha límite.
local function endOfDay(year, month, day)
    return os.time({ year = year, month = month, day = day, hour = 23, min = 59, sec = 59 })
end

function TodoEditDialog.formatDue(due)
    if not due then return nil end
    return os.date("%Y-%m-%d", due)
end

------------------------------------------------------------------------------
-- Alta
------------------------------------------------------------------------------

--- Alta rápida: un único campo de título, más un acceso a la edición completa.
--- @param opts table|nil `title` inicial y `book` al que vincular la tarea.
function TodoEditDialog.showAdd(store, opts, on_done)
    opts = opts or {}
    local dialog
    dialog = InputDialog:new{
        title = _("New task"),
        input = opts.title or "",
        input_hint = _("What needs to be done?"),
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("More…"),
                callback = function()
                    local task, err = store:add({
                        title = dialog:getInputText(),
                        book = opts.book,
                    })
                    if not task then return TodoEditDialog.showError(err) end
                    UIManager:close(dialog)
                    if on_done then on_done(task) end
                    TodoEditDialog.showEdit(store, task, on_done)
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local task, err = store:add({
                        title = dialog:getInputText(),
                        book = opts.book,
                    })
                    if not task then return TodoEditDialog.showError(err) end
                    UIManager:close(dialog)
                    if on_done then on_done(task) end
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

------------------------------------------------------------------------------
-- Edición
------------------------------------------------------------------------------

--- Menú de edición completa de una tarea.
function TodoEditDialog.showEdit(store, task, on_done)
    local dialog
    dialog = ButtonDialog:new{
        title = task.title,
        title_align = "center",
        buttons = {
            {{
                text = _("Edit title"),
                callback = function()
                    UIManager:close(dialog)
                    TodoEditDialog.editTitle(store, task, on_done)
                end,
            }},
            {{
                text = _("Edit notes"),
                callback = function()
                    UIManager:close(dialog)
                    TodoEditDialog.editNotes(store, task, on_done)
                end,
            }},
        },
    }
    UIManager:show(dialog)
end

function TodoEditDialog.editTitle(store, task, on_done)
    local dialog
    dialog = InputDialog:new{
        title = _("Edit title"),
        input = task.title,
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local updated, err = store:update(task.id, { title = dialog:getInputText() })
                    -- Un título vacío se rechaza y la tarea conserva el anterior.
                    if not updated then return TodoEditDialog.showError(err) end
                    UIManager:close(dialog)
                    if on_done then on_done(task) end
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function TodoEditDialog.editNotes(store, task, on_done)
    local dialog
    dialog = InputDialog:new{
        title = _("Notes"),
        input = task.notes or "",
        allow_newline = true,
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local updated, err = store:update(task.id, { notes = dialog:getInputText() })
                    if not updated then return TodoEditDialog.showError(err) end
                    UIManager:close(dialog)
                    if on_done then on_done(task) end
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

--- Selector de fecha límite, con la opción de dejar la tarea sin plazo.
function TodoEditDialog.editDue(store, task, on_done)
    local seed = task.due or store:now()
    local parts = os.date("*t", seed)
    UIManager:show(DateTimeWidget:new{
        year = parts.year,
        month = parts.month,
        day = parts.day,
        title_text = _("Due date"),
        ok_text = _("Set date"),
        -- El botón extra limpia el plazo; el widget se cierra solo tras aplicar.
        extra_text = _("No date"),
        extra_callback = function(picker)
            local updated, err = store:update(task.id, { due = false })
            if not updated then return TodoEditDialog.showError(err) end
            UIManager:close(picker)
            if on_done then on_done(task) end
        end,
        callback = function(picked)
            local updated, err = store:update(task.id, {
                due = endOfDay(picked.year, picked.month, picked.day),
            })
            if not updated then return TodoEditDialog.showError(err) end
            if on_done then on_done(task) end
        end,
    })
end

function TodoEditDialog.editPriority(store, task, on_done)
    local dialog
    local function pick(level)
        return {
            text = PRIORITY_TEXT[level],
            enabled = task.priority ~= level,
            callback = function()
                local updated, err = store:update(task.id, { priority = level })
                if not updated then return TodoEditDialog.showError(err) end
                UIManager:close(dialog)
                if on_done then on_done(task) end
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = _("Priority"),
        title_align = "center",
        buttons = {
            { pick(TodoStore.PRIORITY.HIGH) },
            { pick(TodoStore.PRIORITY.NORMAL) },
            { pick(TodoStore.PRIORITY.LOW) },
        },
    }
    UIManager:show(dialog)
end

return TodoEditDialog
