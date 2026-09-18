--[[--
Lista de tareas para KOReader.

Permite anotar, consultar y completar tareas desde el gestor de archivos o
mientras se lee, vinculándolas opcionalmente a un libro y una página.

@module koplugin.todolist
--]]--

local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local TodoEditDialog = require("todoeditdialog")
local TodoListView = require("todolistview")
local TodoStore = require("todostore")
local ffiUtil = require("ffi/util")
local util = require("util")
local T = ffiUtil.template
local _ = require("gettext")

local TodoList = WidgetContainer:extend{
    name = "todolist",
    is_doc_only = false,
}

-- El almacén y el salto pendiente viven en la clase, no en la instancia:
-- KOReader crea un plugin por interfaz (gestor de archivos y lector) y ambas
-- deben compartir los mismos datos.
TodoList.store = nil
TodoList.pending_jump = nil

local function fileExists(path)
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if ok and lfs then
        return lfs.attributes(path, "mode") == "file"
    end
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

------------------------------------------------------------------------------
-- Ciclo de vida
------------------------------------------------------------------------------

function TodoList:onDispatcherRegisterActions()
    Dispatcher:registerAction("todolist_show", {
        category = "none",
        event = "ShowTodoList",
        title = _("To-do list"),
        general = true,
    })
    Dispatcher:registerAction("todolist_add", {
        category = "none",
        event = "AddTodoTask",
        title = _("To-do list: new task"),
        general = true,
    })
    Dispatcher:registerAction("todolist_add_from_book", {
        category = "none",
        event = "AddTodoTaskFromBook",
        title = _("To-do list: new task for this book"),
        general = true,
    })
end

function TodoList:init()
    self:onDispatcherRegisterActions()
    if not TodoList.store then
        TodoList.store = TodoStore:open()
    end
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    if self.ui and self.ui.highlight then
        self:registerHighlightButton()
    end
end

function TodoList:addToMainMenu(menu_items)
    menu_items.todo_list = {
        text_func = function()
            local pending = TodoList.store:counts().pending
            if pending > 0 then
                return T(_("To-do list (%1)"), pending)
            end
            return _("To-do list")
        end,
        sorting_hint = "more_tools",
        callback = function() self:onShowTodoList() end,
    }
end

--- Red de seguridad: el almacén ya escribe tras cada mutación.
function TodoList:onFlushSettings()
    if TodoList.store then
        TodoList.store:flush()
    end
end

------------------------------------------------------------------------------
-- Contexto del documento abierto
------------------------------------------------------------------------------

function TodoList:getCurrentPage()
    local ui = self.ui
    if not ui then return nil end
    if ui.paging and ui.paging.current_page then
        return ui.paging.current_page
    end
    if ui.rolling and ui.document then
        local ok, page = pcall(function() return ui.document:getCurrentPage() end)
        if ok then return page end
    end
    if ui.view and ui.view.state then
        return ui.view.state.page
    end
    return nil
end

--- Devuelve `{ path, title, page }` del documento abierto, o nil si no hay ninguno.
function TodoList:getBookContext()
    local ui = self.ui
    if not ui or not ui.document or not ui.document.file then return nil end
    local path = ui.document.file
    local title
    if ui.doc_props then
        title = ui.doc_props.display_title or ui.doc_props.title
    end
    return {
        path = path,
        title = title or ffiUtil.basename(path),
        page = self:getCurrentPage(),
    }
end

------------------------------------------------------------------------------
-- Acciones
------------------------------------------------------------------------------

function TodoList:onShowTodoList()
    local view
    view = TodoListView:new{
        store = TodoList.store,
        book = self:getBookContext(),
        go_to_book = function(task)
            UIManager:close(view)
            self:goToBook(task)
        end,
    }
    UIManager:show(view)
    view:warnAboutStoreState()
    return true
end

function TodoList:onAddTodoTask()
    TodoEditDialog.showAdd(TodoList.store, {}, function() end)
    return true
end

function TodoList:onAddTodoTaskFromBook()
    local book = self:getBookContext()
    if not book then
        UIManager:show(InfoMessage:new{
            text = _("There is no book open to link the task to."),
        })
        return true
    end
    TodoEditDialog.showAdd(TodoList.store, { book = book }, function() end)
    return true
end

--- Alta a partir de una selección de texto del lector.
function TodoList:addTaskFromSelection(text)
    TodoEditDialog.showAdd(TodoList.store, {
        title = text,
        book = self:getBookContext(),
    }, function() end)
end

function TodoList:registerHighlightButton()
    self.ui.highlight:addToHighlightDialog("12_todolist", function(this)
        return {
            text = _("Add to to-do list"),
            enabled = true,
            callback = function()
                local text = ""
                if this.selected_text and this.selected_text.text then
                    text = util.cleanupSelectedText(this.selected_text.text)
                end
                self:addTaskFromSelection(text)
                this:onClose()
            end,
        }
    end)
end

------------------------------------------------------------------------------
-- Salto al libro vinculado
------------------------------------------------------------------------------

function TodoList:goToBook(task)
    if not task.book or not task.book.path then return end
    local path = task.book.path

    if not fileExists(path) then
        UIManager:show(InfoMessage:new{
            text = T(_("The book “%1” is no longer available on this device."),
                     task.book.title or path),
        })
        return
    end

    local ui = self.ui
    if ui and ui.document and ui.document.file == path then
        if task.book.page then
            if ui.link then ui.link:addCurrentLocationToStack() end
            ui:handleEvent(Event:new("GotoPage", task.book.page))
        end
        return
    end

    -- Otro documento: se abre y el salto se completa cuando el lector avisa
    -- de que está listo.
    TodoList.pending_jump = { path = path, page = task.book.page }
    local ReaderUI = require("apps/reader/readerui")
    ReaderUI:showReader(path)
end

function TodoList:onReaderReady()
    local jump = TodoList.pending_jump
    if not jump then return end
    if not (self.ui and self.ui.document and self.ui.document.file == jump.path) then
        return
    end
    TodoList.pending_jump = nil
    if not jump.page then return end
    UIManager:nextTick(function()
        self.ui:handleEvent(Event:new("GotoPage", jump.page))
    end)
end

return TodoList
