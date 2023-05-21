
local FileHandler = assert(core:load_global_script('script.zenq_twui_reloader.file_handler'))   ---@module "script.zenq_twui_reloader.file_handler"
local utils       = assert(core:load_global_script('script.zenq_twui_reloader.utils'))          ---@module "script.zenq_twui_reloader.utils"
local t           = assert(core:load_global_script('script.zenq_twui_reloader.tracking'))       ---@module "script.zenq_twui_reloader.tracking"
local c           = require('script.zenq_twui_reloader.const')                                  ---@module "script.zenq_twui_reloader.const"


local log = utils.log




---@class LayoutReloader
---@field recursive boolean
---@field private _file_handler FileHandler
---@field private _orig_funcs {core__get_or_create_component: Core__get_or_create_component_Func, UIRoot__CreateComponent: UIRoot__CreateComponent_Func}
---@field private _sub_layouts {[string]: {tracked: CountedStrArray, default: CountedStrArray}}
---@field private _layout_path_to_file_path {[string]: string}
---@field private __index LayoutReloader
local LayoutReloader = {}


local function _show_welcome_window()
    local ui_root = core:get_ui_root()
    local uic = UIComponent(ui_root:CreateComponent(c.MOD_INFO_POPUP_NAME, c.MOD_INFO_POPUP_LAYOUT))
    
    if uic:IsValid() then
        log('Welcome window created')
    else
        log('Failed to create Welcome window')
    end
end


--- at the moment this function is called UIC:CreateComponent must not be patched!
local function _check_tmp_files()
    local is_files_checked = core:svr_load_bool(c.SVR__IS_FILES_CHECKED)
    if not is_files_checked then
        if not utils.check_tmp_files_existence__fast() then
            log('No temp files found! Creating them...')
            
            utils.create_tmp_files_for_subdir(c.TMP_XML_DIR, '.xml')
            utils.create_tmp_files_for_subdir(c.TMP_TWUI_XML_DIR, '.twui.xml')

            log('Temp files created')

            _show_welcome_window()
        end

        utils.save_svr_number(c.SVR__NEXT_FREE_XML_ID)
        utils.save_svr_number(c.SVR__NEXT_FREE_TWUI_XML_ID)

        core:svr_save_bool(c.SVR__IS_FILES_CHECKED, true)
    end
end



--==================================================================================================================================--
--                                                              LayoutReloader
--==================================================================================================================================--



---@generic Cls: LayoutReloader
---@param cls Cls
---@param recursive boolean? `true` is default
---@return Cls
function LayoutReloader.setup(cls, recursive)  ---@cast cls LayoutReloader
    if type(recursive) ~= 'boolean' then recursive = true end
    
    local self = core:get_static_object(c.MOD_STATIC_NAME) --[[@as LayoutReloader?]]

    if not self then
        self = cls:_new(recursive)
        assert(core:add_static_object(c.MOD_STATIC_NAME, self), 'failed to register LayoutReloader as static object')
        
        log('created new LayoutReloader')
        return self
    end

    if recursive ~= self.recursive then
        local old_value = self.recursive
        self.recursive = recursive

        log('LayoutReloader property "recursive" changed: "'..tostring(old_value)..'" -> "'..tostring(recursive)..'"')

        assert(core:add_static_object(c.MOD_STATIC_NAME, self, nil, true), 'failed to overwrite LayoutReloader static object')
        
        log('stored LayoutReloader static object modified')
    end

    log('LayoutReloader:new() - static object returned')
    return self
end 


--- Creates a UI component with the supplied name, or **recreate** it if it's already been created.
---@param name string Name to give uicomponent.
---@param layout_path string File path to uicomponent layout, from the working data folder.
---@param parent UIC? optional, default value=ui_root Parent uicomponent.
---@return UIC #created uicomponent 
function LayoutReloader.create_or_recreate_component(name, layout_path, parent)
    log(("LayoutReloader.create_or_recreate_component('%s', '%s', <%s>)"):format(name, layout_path, tostring(parent)))

    if not is_uicomponent(parent) then parent = core:get_ui_root() end  ---@cast parent UIC
    
    local uic = find_uicomponent(parent, name)
    if uic then
        uic:Destroy()  
        log('   old component destroyed: ' .. tostring(uic))
    end
    
    uic = UIComponent(parent:CreateComponent(name, layout_path))
    log('   new component created:   ' .. tostring(uic))

    return uic
end


---@private
---@generic Cls: LayoutReloader
---@param cls Cls
---@param recursive boolean
---@return Cls
function LayoutReloader._new(cls, recursive)
    _check_tmp_files()
    local file_handler = assert(FileHandler:new(log), 'Failed to create FileHandler')

    cls.__index = cls
    local self = setmetatable({}, cls)  --[[@as LayoutReloader]]

    self.recursive = recursive
    self._sub_layouts = {}
    self._layout_path_to_file_path = {}
    self._file_handler = file_handler

    self:_patch_component_creation_funcs()

    core:add_ui_destroyed_callback(function()
        self:_destroy() ---@diagnostic disable-line: invisible
    end)

    return self
end 


---@private
function LayoutReloader:_destroy()
    self._file_handler:shutdown()
    log('LayoutReloader destroyed')
end


---@private
function LayoutReloader:_patch_component_creation_funcs()
    local ui_root_mt = getmetatable(core:get_ui_root())

    self._orig_funcs = self._orig_funcs or {
        core__get_or_create_component = core.get_or_create_component,
        UIRoot__CreateComponent       = ui_root_mt.CreateComponent,
    }

    core.get_or_create_component = function(core_obj, name, path, ...)   ---@diagnostic disable-line: duplicate-set-field
        local new_path = self:_process_path(path)
        if new_path then
            log('core.get_or_create_component: old_path = "' .. tostring(path) .. '"; new_path = "'.. tostring(new_path) ..'"')    
            path = new_path
        end
        return self._orig_funcs.core__get_or_create_component(core_obj, name, path, ...)
    end

    ui_root_mt.CreateComponent = function(ui_root_obj, name, path, ...)
        local new_path = self:_process_path(path)
        if new_path then
            log('CreateComponent: old_path = "' .. tostring(path) .. '"; new_path = "'.. tostring(new_path) ..'"')
            path = new_path
        end
        return self._orig_funcs.UIRoot__CreateComponent(ui_root_obj, name, path, ...)
    end
end


---@private
---@param filepath string file must exist!
---@return string datetime string in format: `DDMMYY_HHmmss` (ex: `150523_190216`)
function LayoutReloader:_get_file_modification_datetime(filepath)
    filepath = filepath:gsub('/', [[\]])
    
    local output = self._file_handler:get_file_modification_datetime(filepath)

    utils.assert_type(output, 'string', 'output')  ---@cast output string
    local datetime = assert(output:match(c.DATETIME_FORMAT_REGEX), 'failed to extract last write time from <output> = "'..output..'"')

    return datetime
end


---@private
---@param path_without_ext string
---@return string? tmp_layout_path
function LayoutReloader:_process_sub_layout(path_without_ext)
    ---@diagnostic disable-next-line: unknown-cast-variable
    ---@cast core core

    log('processing sub layout file:  "'..path_without_ext..'"')

    if utils.is_temp_path(path_without_ext) then return end

    local local_path_without_ext = utils.prepend_local_data_folder(path_without_ext)
    local local_path = utils.check_against_file_valid_extensions(local_path_without_ext) 

    if not local_path then
        return
    end

    local tmp_layout_path = self:_get_uniq_file_path_per_modification(local_path)
    local uic = self._orig_funcs.core__get_or_create_component(core, utils.get_random_string(), tmp_layout_path)  --TODO: use UIComponent:CreateComponent() instead?

    assert(uic:IsValid(), 'Created sub layout UI Element is invalid. Was game restarted after temp failes creation?)')
    uic:Destroy()

    local tmp_layout_path_without_ext = utils.remove_extension(tmp_layout_path)
    utils.log_separator()
    log('result:  "'..path_without_ext..'"  ->  "'..tmp_layout_path_without_ext..'"')

    return tmp_layout_path_without_ext
end


---@private
---@param path string
---@param layout string
---@return string?
function LayoutReloader:_modify_sub_layouts(path, layout)
    local tmp_path
    
    local modified_layout = layout
    local sub_layouts = {}
    local processed_layouts = {}
    local found, processed = 0, 0

    for sub_layout_path in utils.layout_fields_iterator(layout) do
        utils.enter_sub_layout_processing_log_context()

        if processed_layouts[sub_layout_path] then
            tmp_path = processed_layouts[sub_layout_path]
            log('already processed')
        else
            tmp_path = self:_process_sub_layout(sub_layout_path)
        end

        if tmp_path then
            processed_layouts[sub_layout_path] = tmp_path
            modified_layout = modified_layout:gsub('value="'..sub_layout_path..'"', 'value="'..tmp_path..'"', 1)

            processed = processed + 1
        end

        found = found + 1       
        utils.leave_sub_layout_processing_log_context()
    end

    sub_layouts.count = found
    self._sub_layouts[path] = sub_layouts

    log('  sub layouts processing results:  processed/found  =  '..processed..'/'..found)

    return (processed > 0) and modified_layout or nil
end


---@private
---@param path string
---@return string new_path
function LayoutReloader:_get_uniq_file_path_per_modification(path)
    local stored_m_dt, tmp_filepath = t.load_file_info(path)
    local current_m_dt = self:_get_file_modification_datetime(path)

    if self:_is_actual_file_stored(stored_m_dt, current_m_dt, path) then  ---@cast tmp_filepath string
        return utils.normalize_path(tmp_filepath, path)
    end

    log('  rotate file content')
    local layout = utils.read_file_content(path)

    if self.recursive then
        log('  check sub layouts')
        layout = self:_modify_sub_layouts(path, layout) or layout
    end

    tmp_filepath = t.get_next_free_file(path)
    utils.write_content_to_file(tmp_filepath, layout)
    t.store_file_info(path, current_m_dt, tmp_filepath)

    return utils.normalize_path(tmp_filepath, path)
end


---@private
---@param path string
---@return string? new_path
function LayoutReloader:_process_path(path)
    utils.assert_type(path, 'string', 'path')

    local local_path = utils.get_path_for_processing(path) 
    if not local_path then
        log(tostring(path) .. '  -  skipped  (not a local layout or temporary file)')
        return
    end  ---@cast local_path string

    log(path .. ' -> ' .. local_path .. '  -  processing')
    return self:_get_uniq_file_path_per_modification(local_path)
end


---@private
---@param stored_file_modification_datetime string?
---@param last_file_modification_datetime string
---@param path string
---@param results_cache {[string]: true} | nil
---@return boolean
function LayoutReloader:_is_actual_file_stored(stored_file_modification_datetime, last_file_modification_datetime, path, results_cache)
    if stored_file_modification_datetime ~= last_file_modification_datetime then
        return false
    end

    if not self.recursive then
        return true
    end
    
    if not results_cache then
        results_cache = {}  ---@type {[string]: true}
    end

    ---TODO: store/return "layout" to parent (avoid extra file read)?         
    local layout = utils.read_file_content(path)

    for sub_layout_path in utils.layout_fields_iterator(layout) do
        if self:__is_sub_layout_changed(sub_layout_path, results_cache) then
            return false
        end
    end

    return true
end


---@private
---@param sub_path string
---@param is_not_changed {[string]: true}
function LayoutReloader:__is_sub_layout_changed(sub_path, is_not_changed)
    if is_not_changed[sub_path] then
        return false
    end

    local local_sub_path = utils.get_path_for_processing(sub_path) 
    if not local_sub_path then
        is_not_changed[sub_path] = true
        return false
    end

    if self:_is_actual_file_stored(
        t.load_file_info(local_sub_path),
        self:_get_file_modification_datetime(local_sub_path),
        local_sub_path,
        is_not_changed
    ) then
        is_not_changed[sub_path] = true
        return false
    end
        
    return true
end


return LayoutReloader
