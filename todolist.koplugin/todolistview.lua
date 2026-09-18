--[[--
Pantalla de la lista de tareas.

Envuelve el widget `Menu` de KOReader: proyecta cada tarea del almacén a una
entrada de `item_table` y traduce los gestos en operaciones sobre el almacén.
Nunca escribe en disco directamente.

@module todolist.todolistview
--]]--

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local TodoEditDialog = require("todoeditdialog")
local TodoStore = require("todostore")
local T = require("ffi/util").template
local _ = require("gettext")

local FILTER_TEXT = {
    all = _("All"),
    pending = _("Pending"),
    done = _("Done"),
    overdue = _("Overdue"),
    book = _("This book"),
}

local SORT_TEXT = {
    created = _("Creation order"),
    due = _("Due date"),
    priority = _("Priority"),
    title = _("Title"),
}

local TodoListView = Menu:extend{
    is_popout = false,
    is_borderless = true,
    covers_fullscreen = true,
    title_bar_left_icon = "appbar.menu",
    -- Inyectados por quien abre la vista.
    store = nil,
    book = nil,        -- contexto del documento abierto: { path, title, page }
    go_to_book = nil,  -- función que salta al libro de una tarea
}

function TodoListView:init()
    self.book_path = self.book and self.book.path or nil
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.item_table = self:genItemTable()
    self.title = self:genTitle()
    Menu.init(self)
end

------------------------------------------------------------------------------
-- Construcción de la lista
------------------------------------------------------------------------------

--- El filtro «de este libro» no es aplicable sin documento abierto: en ese
--- caso se cae a «todas» en lugar de mostrar una lista vacía sin explicación.
function TodoListView:effectiveFilter()
    local filter = self.store.view.filter
    if filter == "book" and not self.book_path then
        return "all"
    end
    return filter
end

function TodoListView:genItem(task, now)
    local marker = task.done and "[x] " or "[ ] "
    local mandatory = TodoEditDialog.formatDue(task.due)
    if mandatory and self.store:isOverdue(task, now) then
        -- Marca textual de vencida: legible con cualquier tema y tamaño de fuente.
        mandatory = "! " .. mandatory
    end
    return {
        text = marker .. task.title,
        mandatory = mandatory,
        bold = (not task.done) and task.priority == TodoStore.PRIORITY.HIGH or false,
        dim = task.done,
        task_id = task.id,
    }
end

function TodoListView:genItemTable()
    local now = self.store:now()
    local tasks = self.store:list({
        filter = self:effectiveFilter(),
        book_path = self.book_path,
        now = now,
    })

    -- El alta va como primera fila fija: el widget `Menu` no ofrece un icono
    -- derecho en su barra de título donde colocarla.
    local items = {
        { text = _("+ New task"), is_add = true, bold = true },
    }

    if #tasks == 0 then
        items[#items + 1] = {
            text = _("No tasks to show with the current filter. Tap “+ New task” to add one."),
            dim = true,
            is_empty_notice = true,
        }
    end

    for _, task in ipairs(tasks) do
        items[#items + 1] = self:genItem(task, now)
    end

    self.shown_count = #tasks
    return items
end

function TodoListView:genTitle()
    local counts = self.store:counts()
    local filter_text = FILTER_TEXT[self:effectiveFilter()] or FILTER_TEXT.all
    if self.store:isReadOnly() then
        return T(_("%1 (%2 of %3) — read only"), filter_text, self.shown_count or 0, counts.total)
    end
    return T(_("%1 (%2 of %3)"), filter_text, self.shown_count or 0, counts.total)
end

--- Reconstruye la tabla completa. Se usa cuando cambia el conjunto de la lista:
--- alta, borrado, cambio de filtro o de orden.
function TodoListView:refreshList(index)
    self.item_table = self:genItemTable()
    self:switchItemTable(self:genTitle(), self.item_table, index or 1)
end

--- Actualiza una sola fila sin reconstruir la tabla, para que alternar el
--- estado de una tarea no provoque un refresco completo de la lista.
function TodoListView:refreshItem(item)
    local task = self.store:get(item.task_id)
    if not task then return self:refreshList(1) end

    local index
    for i, candidate in ipairs(self.item_table) do
        if candidate == item then
            index = i
            break
        end
    end
    if not index then return self:refreshList(1) end

    local fresh = self:genItem(task, self.store:now())
    for key, value in pairs(fresh) do
        item[key] = value
    end
    -- Una tarea que deja de cumplir el filtro activo no desaparece hasta el
    -- siguiente refresco completo: así un toque accidental se puede deshacer.
    self.title = self:genTitle()
    self:updateItems(index)
end

------------------------------------------------------------------------------
-- Interacción
------------------------------------------------------------------------------

function TodoListView:onMenuSelect(item)
    if item.is_add then
        self:addTask()
        return true
    end
    if not item.task_id then return true end

    local task, err = self.store:toggle(item.task_id)
    if not task then
        TodoEditDialog.showError(err)
        return true
    end
    self:refreshItem(item)
    return true
end

function TodoListView:onMenuHold(item)
    if not item.task_id then return true end
    local task = self.store:get(item.task_id)
    if not task then
        self:refreshList(1)
        return true
    end

    local dialog
    local function after_change()
        self:refreshList(self:indexOfTask(task.id))
    end

    dialog = ButtonDialog:new{
        title = task.title,
        title_align = "center",
        buttons = {
            {{
                text = _("Edit"),
                callback = function()
                    UIManager:close(dialog)
                    TodoEditDialog.showEdit(self.store, task, after_change)
                end,
            }},
            {{
                text = _("Due date"),
                callback = function()
                    UIManager:close(dialog)
                    TodoEditDialog.editDue(self.store, task, after_change)
                end,
            }},
            {{
                text = _("Priority"),
                callback = function()
                    UIManager:close(dialog)
                    TodoEditDialog.editPriority(self.store, task, after_change)
                end,
            }},
            {{
                text = _("Go to book"),
                enabled = task.book ~= nil and self.go_to_book ~= nil,
                callback = function()
                    UIManager:close(dialog)
                    self.go_to_book(task)
                end,
            }},
            {{
                text = _("Delete"),
                callback = function()
                    UIManager:close(dialog)
                    self:confirmDelete(task)
                end,
            }},
        },
    }
    UIManager:show(dialog)
    return true
end

function TodoListView:indexOfTask(id)
    for i, item in ipairs(self.item_table) do
        if item.task_id == id then return i end
    end
    return 1
end

function TodoListView:addTask()
    -- Una tarea creada con un libro abierto queda vinculada a él.
    TodoEditDialog.showAdd(self.store, { book = self.book }, function(task)
        self:refreshList(self:indexOfTask(task.id))
    end)
end

function TodoListView:confirmDelete(task)
    UIManager:show(ConfirmBox:new{
        text = T(_("Do you want to delete “%1”?"), task.title),
        ok_text = _("Delete"),
        ok_callback = function()
            local ok, err = self.store:remove(task.id)
            if not ok then
                TodoEditDialog.showError(err)
                return
            end
            self:refreshList(1)
        end,
    })
end

------------------------------------------------------------------------------
-- Filtros y ordenación
------------------------------------------------------------------------------

function TodoListView:onLeftButtonTap()
    local dialog

    local function filterButton(key)
        return {
            text = FILTER_TEXT[key],
            -- El filtro por libro no es aplicable fuera del lector.
            enabled = not (key == "book" and not self.book_path)
                and self.store.view.filter ~= key,
            callback = function()
                UIManager:close(dialog)
                self.store:setView(key, nil)
                self:refreshList(1)
            end,
        }
    end

    local function sortButton(key)
        return {
            text = SORT_TEXT[key],
            enabled = self.store.view.sort ~= key,
            callback = function()
                UIManager:close(dialog)
                self.store:setView(nil, key)
                self:refreshList(1)
            end,
        }
    end

    dialog = ButtonDialog:new{
        title = _("Filter and sort"),
        title_align = "center",
        buttons = {
            { filterButton("all"), filterButton("pending") },
            { filterButton("done"), filterButton("overdue") },
            { filterButton("book") },
            { sortButton("created"), sortButton("due") },
            { sortButton("priority"), sortButton("title") },
        },
    }
    UIManager:show(dialog)
    return true
end

function TodoListView:onClose()
    UIManager:close(self)
    if self.close_callback then self.close_callback() end
    return true
end

--- Aviso mostrado al abrir un almacén que venía corrupto o de una versión futura.
function TodoListView:warnAboutStoreState()
    if self.store.was_corrupt then
        UIManager:show(InfoMessage:new{
            text = _("The to-do list file could not be read. A copy of the original was kept next to it with the .bak extension, and an empty list was started."),
        })
    elseif self.store:isReadOnly() then
        UIManager:show(InfoMessage:new{
            text = _("This to-do list was written by a newer version of the plugin. It is shown read only so its data is not damaged."),
        })
    end
end

return TodoListView
