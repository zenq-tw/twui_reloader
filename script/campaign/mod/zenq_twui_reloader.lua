local LayoutReloader = assert(core:load_global_script('script.zenq_twui_reloader.main'))  ---@module 'script.zenq_twui_reloader.main'


cm:add_pre_first_tick_callback(function ()
    LayoutReloader:setup()
end)
