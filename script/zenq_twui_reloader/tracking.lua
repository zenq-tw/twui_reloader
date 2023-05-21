local utils       = assert(core:load_global_script('script.zenq_twui_reloader.utils'))          ---@module "script.zenq_twui_reloader.utils"
local c           = require('script.zenq_twui_reloader.const')                                  ---@module "script.zenq_twui_reloader.const"


local tracking = {}


---@param path string
---@return string svr_key
local function make_svr_key_for_path(path)
    return c.SVR_KEYS_PREFIX .. path:gsub('[/\\]', '|'):gsub('%s', '-')
end


--==================================================================================================================================--
--                                                     tracked files info
--==================================================================================================================================--


---@param filepath string
---@param svr_id_key string
---@param ext string WITHOUT LEADING DOT !!
---@return string new_filepath
local function _get_next_free_file(filepath, ext, svr_id_key, tmp_dir)
    local id = utils.load_svr_number(svr_id_key)

    filepath = tmp_dir .. id .. '.' .. ext
    assert(utils.is_file_exist(filepath), 'tmp file not found: "'..filepath..'"')

    id = id + 1
    assert(id <= c.TMP_FILE_MAX_ID, 'temporary files cap exceeded = ' .. tostring(c.TMP_FILE_MAX_ID))
    utils.save_svr_number(svr_id_key, id)

    return filepath
end


---@param path string
---@return string? datetime, string? tmp_filepath
function tracking.load_file_info(path)
    local svr_key = make_svr_key_for_path(path)
    local dumped_info = core:svr_load_string(svr_key)
    utils.log('load_file_info:  svr_key="'..svr_key..'"   dumped_info="'..dumped_info..'"')

    if not dumped_info or dumped_info == '' then return end

    assert(dumped_info:find(c.SVR_FILE_INFO_DELIM), 'Invalid dumped info: "'..dumped_info..'" (no delimeter found = "'..c.SVR_FILE_INFO_DELIM..'")')

    return unpack(dumped_info:split(c.SVR_FILE_INFO_DELIM))
end


---@param path string
---@param datetime string
---@param tmp_filepath string
function tracking.store_file_info(path, datetime, tmp_filepath)
    local svr_key = make_svr_key_for_path(path)
    local dumped_info = datetime .. c.SVR_FILE_INFO_DELIM .. tmp_filepath

    utils.log('store_file_info:  svr_key="'..svr_key..'"   dumped_info="'..dumped_info..'"')

    core:svr_save_string(svr_key, dumped_info)
end






---@param filepath string
---@return string new_filepath
function tracking.get_next_free_file(filepath)
    local svr_key, tmp_dir
    local _, _, file_ext = utils.parse_filepath(filepath)

    if file_ext:find('twui.xml') then
        svr_key, tmp_dir = c.SVR__NEXT_FREE_TWUI_XML_ID,  c.TMP_TWUI_XML_DIR
    else
        svr_key, tmp_dir = c.SVR__NEXT_FREE_XML_ID,       c.TMP_XML_DIR
    end
    
    return _get_next_free_file(filepath, file_ext, svr_key, tmp_dir)
end


return tracking
