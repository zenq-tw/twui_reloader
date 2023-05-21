local utils  = assert(core:load_global_script('script.zenq_twui_reloader.utils'))          ---@module "script.zenq_twui_reloader.utils"
local c      = require('script.zenq_twui_reloader.const')                                  ---@module "script.zenq_twui_reloader.const"


---@class FileHandler
---@field private _worker file*
---@field private _transmitter  file*
---@field private _log_func fun(msg): nil
---@field private __index FileHandler
local FileHandler = {}


---@nodiscard
---@generic Cls: FileHandler
---@param cls Cls
---@param log_func fun(msg): nil
---@return nil | Cls
function FileHandler.new(cls, log_func)
    local self, worker, transmitter, err

    cls.__index = cls
    
    self = setmetatable({}, cls) --[[@as FileHandler]]
    self._log_func    = log_func
    
    self:_create_scripts()

    worker, err = io.popen(c.WORKER, 'w') 
    if not worker then
        log_func('[FileHandler] Failed to spawn suprocess "'..c.WORKER_SCRIPT..'": "'..tostring(err)..'"')
        return
    end

    transmitter, err = io.popen(c.TRANSMITTER, 'r') 
    if not transmitter then
        log_func('[FileHandler] Failed to spawn suprocess "'..c.WORKER_SCRIPT..'": "'..tostring(err)..'"')
        return
    end


    self._worker, self._transmitter = worker, transmitter
    


    local max_time = math.ceil(math.ceil(c.SUBPROC_SELF_MAX_WAITING_SIBLING_TIME__SEC * 2 + 1))
    local st_time  = os.clock()

    --- skip bullshit produced by several of the PowerShell commands at script startup
    while os.clock() - st_time < max_time do
        if self:_get_results() == 'START' then
            break
        end
    end


    if self:_is_workers_unavailable() then
        log_func("[FileHandler] Failed to create FileHandler: subprocess(es) didn't start")
        self:shutdown()
        return
    end

    return self
end


---tries to close sub processes and release related lua resources
---#### NOTE: you _should_ call this function before exit from application!
function FileHandler:shutdown()
    self._close_pipe(self._worker)  --NOTE: must be first!
    self._close_pipe(self._transmitter)
    
    self._worker = nil
    self._transmitter = nil
end


---@param filepath string
---@return string? datetime
function FileHandler:get_file_modification_datetime(filepath)
    if self:_is_workers_unavailable() then
        self._log_func('[FileHandler] failed to get file modification dt  -  sub workers unavailable')
        return
    end

    if not filepath then
        self._log_func('[FileHandler] filepath invalid')
        return
    end

    self._log_func('[FileHandler] extracting file modification dt for: "'.. filepath ..'"')

    self:_send_request(filepath)

    local response = self:_get_results()
    if response then
        self._log_func("[FileHandler] result: " .. tostring(response))
        return response
    end

    self._log_func("[FileHandler] failed (sub workers terminated?)")
end





---@private
function FileHandler:_create_scripts()
    if core:svr_load_bool(c.SVR_KEY__SCRIPTS_CREATED) then
        self._log_func('[FileHandler] "scripts_created" flag turned on -> skip scripts creation')
        return
    end

    local script, file, err_msg
    for _, script_name in pairs({c.WORKER_SCRIPT, c.TRANSMITTER_SCRIPT}) do
        script = self._load_script(script_name)
        script = script:gsub('{{([%w_]+)}}', c.TEMPLATE_SCRIPT_ENVS)

        file, err_msg = io.open(script_name, 'w')
        assert(file, '[FileHandler] Failed to open script file for write: "'..script_name..'". Error: "'..tostring(err_msg)..'"')

        file:write(script)
        file:close()
    end

    self._log_func('[FileHandler] scripts created')
    core:svr_save_bool(c.SVR_KEY__SCRIPTS_CREATED, true)
end


-- Function to request modification datetime from worker (pipe)
---@private
---@param filepath string
function FileHandler:_send_request(filepath)
    self._worker:write(filepath .. '\n')
    self._worker:flush()
end


-- Function to retrieve results from worker (pipe)
---@private
---@return string
function FileHandler:_get_results()
    local result = self._transmitter:read('*l')
    return result 
end


---@private
---@return boolean
function FileHandler:_is_workers_unavailable()
    -- check that subprocess pipes still valid lua files
    if io.type(self._worker) ~= 'file' or io.type(self._transmitter) ~= 'file' then
        return true
    end

    -- check for liveness markers: subprocesses should create these files on startup and delete them immediately after they finish 
    --  (unless there is a strange abnormal error and the user does not close the terminal with the X button)
    return not (
        utils.is_file_exist(c.WORKER_ALIVE_MARKER_FILE)
        and
        utils.is_file_exist(c.TRANSMITTER_ALIVE_MARKER_FILE)
    )
end


-- Function to close some pipe)
---@private
function FileHandler._close_pipe(pipe)
    if io.type(pipe) ~= "file" then return end
    pipe:close()
end


---@private
---@param script_name string
---@return string
function FileHandler._load_script(script_name)
    local script_path = c.SCRIPTS_PATH .. script_name .. '.lua'
    
    local content_getter, err_msg = loadfile(script_path)
    assert(content_getter, '[FileHandler] Failed to load script "'..script_name..'". Error: "'..tostring(err_msg)..'"')

    local is_success, data = pcall(content_getter)
    assert(is_success, '[FileHandler] Failed to load script "'..script_name..'". Error: "'..tostring(data)..'"')
    
    return data
end



return FileHandler
