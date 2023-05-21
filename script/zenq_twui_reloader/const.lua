---@class _ZTWUIR_const
local const = {}

const.MOD_STATIC_NAME  = 'zenq_layout_reloader'

const.TMP_FILE_MAX_ID   = 1000


const.TMP_DIR           = 'ui/temp/'
const.TMP_DIR_PATTERN   = 'ui[/\\]temp[/\\]'

const.TMP_XML_DIR       = 'data/' .. const.TMP_DIR .. 'xml/'
const.TMP_TWUI_XML_DIR  = 'data/' .. const.TMP_DIR .. 'twui_xml/'

const.SVR_KEYS_PREFIX     = 'zenq_twui_loader__'
const.SVR_FILE_INFO_DELIM = '|'

const.SVR__IS_FILES_CHECKED      = const.SVR_KEYS_PREFIX .. 'files_checked'
const.SVR__NEXT_FREE_XML_ID      = const.SVR_KEYS_PREFIX .. 'next_free_xml_file_id'
const.SVR__NEXT_FREE_TWUI_XML_ID = const.SVR_KEYS_PREFIX .. 'next_free_twui_xml_file_id'


const.MOD_INFO_POPUP_NAME   = const.MOD_STATIC_NAME .. '_welcome_letter'
const.MOD_INFO_POPUP_LAYOUT = 'ui/common ui/zenq_twui_reloader_configured'


const.DATETIME_FORMAT_REGEX      = '(%d%d%d%d%d%d_%d%d%d%d%d%d)'   -- lua regex has no limiting quantifier support/
const.DATETIME_FORMAT_POWERSHELL = 'ddMMyy_HHmmss'
const.DATETIME_FORMAT_LUA        = '%d%m%y_%H%M%S'


const.ALPHABET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
const.ALPHABET_SIZE = #const.ALPHABET

const.XML_EXT  = '.xml'
const.TWUI_EXT = '.twui.xml'

const.CMD_CREATE_DIR = [[powershell -Command "New-Item -ItemType Directory -Force -Path '%s'"]]


--==================================================================================================================================--
--                                                      FileHandler const
--==================================================================================================================================--



const.SCRIPTS_PATH = 'script/zenq_twui_reloader/scripts/'
const.SVR_KEY__SCRIPTS_CREATED = 'zenq_twui_reloader__scripts_created'
const.SUBPROC_SELF_MAX_WAITING_SIBLING_TIME__SEC = 15
const.TRANSMITTER_READY__MARKER_STRING = 'START'
const.PIPE_NAME = 'twui_reloader_backend__pipe'


do
    local w_name = 'file_handler'
    local t_name = 'transmitter'

    const.WORKER_SCRIPT      = ('twuir_%s.ps1'):format(w_name)
    const.TRANSMITTER_SCRIPT = ('twuir_%s.ps1'):format(t_name)

    const.WORKER_ALIVE_MARKER_FILE      = ('.twuir__%s__is_alive__marker'):format(w_name)
    const.TRANSMITTER_ALIVE_MARKER_FILE = ('.twuir__%s__is_alive__marker'):format(t_name)

    local w_stdout_stderr = ('.twuir__%s__out.txt'):format(w_name)
    local t_log           = ('.twuir__%s__log.txt'):format(t_name)
    local t_stderr        = ('.twuir__%s__err.txt'):format(t_name)

    const.WORKER      = ('powershell -File %s > "%s"  2>&1   '):format(const.WORKER_SCRIPT, w_stdout_stderr)
    const.TRANSMITTER = ('powershell -File %s   "%s"  2>"%s" '):format(const.TRANSMITTER_SCRIPT, t_log, t_stderr)
end


const.TEMPLATE_SCRIPT_ENVS = {
    ['BACKEND_PIPE_NAME']       = const.PIPE_NAME,
    ['WORKER_MARKER_FILE']      = const.WORKER_ALIVE_MARKER_FILE,
    ['TRANSMITTER_MARKER_FILE'] = const.TRANSMITTER_ALIVE_MARKER_FILE,
    ['READY_MARKER_STRING']     = const.TRANSMITTER_READY__MARKER_STRING,
    ['WAITING_FOR_SIBLING_PROCESS_TIME__SECODNS'] = const.SUBPROC_SELF_MAX_WAITING_SIBLING_TIME__SEC
}


--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--



return const
