local c = require('script.zenq_twui_reloader.const')    ---@module "script.zenq_twui_reloader.const"


---@class _ZTWUIR__utils
local utils = {}



--==================================================================================================================================--
--                                                              log
--==================================================================================================================================--



local LOG_LVL = 0


---@param msg string
---@param log_lvl integer?
local log = function (msg, log_lvl)
    local log_lvl_prefix = ('  │ '):rep(math.max(log_lvl or LOG_LVL, 0))

    ModLog('> TWUI Reloader:  ' .. log_lvl_prefix .. msg)
end

utils.log = log


function utils.enter_sub_layout_processing_log_context()
    log('  ┌────────────────────────── sub layout processing ─────────────────────────┐')
    LOG_LVL = LOG_LVL + 1
end

function utils.leave_sub_layout_processing_log_context()
    LOG_LVL = math.min(LOG_LVL - 1, 0)
    log('  └──────────────────────────────────────────────────────────────────────────┘')
end


function utils.log_separator()
    log('  ├────────────────────────────────────────────────────────────────────────── ', math.max(LOG_LVL - 1, 0))
end




--==================================================================================================================================--
--                                                              SVR
--==================================================================================================================================--



---@param svr_key string
---@return number? value
function utils.load_svr_number(svr_key)
    local dumped_value = core:svr_load_string(svr_key)
    if not dumped_value or dumped_value == '' then return end

    local is_success, value_or_err_msg = pcall(tonumber, dumped_value)
    if not is_success then return end

    return value_or_err_msg
end


---@param svr_key string
---@param value? number default is 1
function utils.save_svr_number(svr_key, value)
    if type(value) ~= 'number' then value = 1 end

    core:svr_save_string(svr_key, tostring(value))
end



--==================================================================================================================================--
--                                                            Path
--==================================================================================================================================--


---@param filepath string
---@return boolean
function utils.is_file_exist(filepath)
    local file = io.open(filepath)
    if file then
        file:close()
        return true
    end
    return false
end


---@param filepath string
---@return boolean
function utils.has_any_extension(filepath)
    local _, _, file_ext  = utils.parse_filepath(filepath)
    return file_ext ~= ''
end


---@param path string
---@return string path_without_ext
function utils.remove_extension(path)
    local folder_path, file_name, _, _ = utils.parse_filepath(path)
    return folder_path .. file_name
end


---@param filepath string
---@return string folder_path
---@return string file_name
---@return string file_ext
---@return string separator
function utils.parse_filepath(filepath)
    local folder_path, separator, file_name, file_ext = filepath:match('^(.+([/\\]))(.+)%.(twui%.xml)$')
    if not folder_path then
        folder_path, separator, file_name, file_ext = filepath:match('^(.+([/\\]))(.+)%.(xml)$')
        if not folder_path then
            folder_path, separator, file_name = filepath:match('^(.+([/\\]))(.+)$')
            file_ext = ''
        end
    end

    assert(folder_path and file_name and file_ext and separator, 'failed to parse filepath: "'..tostring(filepath)..'"')

    return folder_path, file_name, file_ext, separator
end



---@param filepath string
---@param orig_path string
---@return string filepath
function utils.normalize_path(filepath, orig_path)
    local orig_slash, invalid_slash

    if orig_path:find('\\') then
        orig_slash, invalid_slash = '\\', '/'
    else
        orig_slash, invalid_slash = '/', '\\'
    end

    filepath = filepath:gsub('data[\\/]', ''):gsub(invalid_slash, orig_slash)

    return filepath
end


---@param path string
---@return string
function utils.prepend_local_data_folder(path)
    if path:find([[\]]) then
        return [[data\]] .. path
    end
    return 'data/' .. path
end


---@param path string
---@return string
function utils.prepend_local_data_folder_safe(path)
    if path:starts_with('data') then return path end
    return utils.prepend_local_data_folder(path)
end



---@param path_without_ext string
---@return string? path
function utils.try_to_determine_file_extension(path_without_ext)
    if utils.is_file_exist(path_without_ext .. c.XML_EXT) then
        return path_without_ext .. c.XML_EXT
    end

    if utils.is_file_exist(path_without_ext .. c.TWUI_EXT) then
        return path_without_ext .. c.TWUI_EXT
    end

    log('file is not a local layout file  -  both options not found:   "'..path_without_ext..c.XML_EXT..'"  and  "'..path_without_ext..c.TWUI_EXT..'")')
end


--==================================================================================================================================--
--                                                        file i/o
--==================================================================================================================================--


---@param filepath string
---@return string
function utils.read_file_content(filepath)
    local file = assert(io.open(filepath), 'failed to open file for read: "'..filepath..'"')
    local content = file:read("*a")
    file:close()

    utils.assert_type(content, 'string', 'file:read("*a")')

    return content
end


---@param filepath string
---@param content string
function utils.write_content_to_file(filepath, content)
    utils.assert_type(content, 'string', 'content')
    
    local file = assert(io.open(filepath, 'w'), 'failed to open file for write: "'..filepath..'"')
    file:write(content)
    file:close()
end



--==================================================================================================================================--
--                                                        tmp files
--==================================================================================================================================--



---@param path string
---@return boolean
function utils.is_temp_path(path)
    return path:find_lua(c.TMP_DIR_PATTERN) ~= nil
end


---@param subdir_path string
---@param ext string
function utils.create_tmp_files_for_subdir(subdir_path, ext)
    log('  Creating temp files for directory: "'..subdir_path..'"')

    os.execute(c.CMD_CREATE_DIR:format(subdir_path))
    for i=1, c.TMP_FILE_MAX_ID do
        assert(io.open(subdir_path .. i .. ext, 'w'), 'Failed to create file: "'..subdir_path..i..ext..'"'):close()
    end
end


---@return boolean
function utils.check_tmp_files_existence__fast()
    local xml_first      = utils.is_file_exist(c.TMP_XML_DIR .. '1.xml')
    local xml_last       = utils.is_file_exist(c.TMP_XML_DIR .. c.TMP_FILE_MAX_ID .. '.xml')
    
    local twui_xml_first = utils.is_file_exist(c.TMP_TWUI_XML_DIR .. '1.twui.xml')
    local twui_xml_last  = utils.is_file_exist(c.TMP_TWUI_XML_DIR .. c.TMP_FILE_MAX_ID .. '.twui.xml')

    return xml_first and xml_last and twui_xml_first and twui_xml_last
end



--==================================================================================================================================--
--                                                              other stuff
--==================================================================================================================================--


---@param obj any
---@param type_name string
---@param obj_repr string
function utils.assert_type(obj, type_name, obj_repr)
    assert(type(obj) == type_name, 'type('..obj_repr..') == "'..type(obj)..'" (must be "'..type_name..'")')
end


function utils.get_random_string()
    local result = ''
    local char_id
    
    for _=1, 16 do
        char_id = math.random(1, c.ALPHABET_SIZE)
        result  = result .. string.sub(c.ALPHABET, char_id, char_id)
    end
    
    return result
end



---@param layout string
---@return fun(): string next
function utils.layout_fields_iterator(layout)
    return layout:gmatch('value="(ui[/\\].-)"')
end


---@param path string
---@return string?
function utils.get_path_for_processing(path)
    path = utils.prepend_local_data_folder(path)

    if not utils.has_any_extension(path) then
        return utils.try_to_determine_file_extension(path)
    end

    if not utils.is_file_exist(path) or utils.is_temp_path(path) then
        return nil
    end

    return path
end


-- Sleep function that pauses execution for the specified number of seconds
---@param seconds integer
function utils.sleep(seconds)
    os.execute('timeout /t ' .. seconds .. ' >nul')
end



--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--


return utils
