local M = {}

local default_plugin_dir = "plugins"
local remote_url = "https://github.com/"
local pack_list = {}  -- absolute links for installations
local config_list = {} -- Configurations for each plugin
local pack_lockfile_content = {}
local pack_lockfile = vim.fn.stdpath("config") .. "/nvim-pack-lock.json"
local plugin_name_list = {} -- The actual names of the plugins
local always_update = false
local confirm_update = false
local confirm_clean = false

---@brief Setup function for the module
---@param simplug_config { 
    ---plugin_dir: string,       --- plugin_dir: location to load plugin configs from (can also be passed to the load function)
    ---always_update: boolean,   --- always_update: whether or not to always run pack.update with load
    ---pack_lockfile: string,    --- pack_lockfile: location of the lockfile if not in the default location
    ---confirm_update: boolean,  --- confirm_update: whether or not to ask the user for confirmation when updating
    ---confirm_clean: boolean }  --- confirm_clean: whether or not to ask the user for confirmations when cleaning
function M.setup(simplug_config)
    default_plugin_dir = simplug_config.plugin_dir or default_plugin_dir
    always_update = simplug_config.always_update or always_update
    pack_lockfile = simplug_config.pack_lockfile or pack_lockfile
    confirm_update = simplug_config.confirm_update or confirm_update
    confirm_clean = simplug_config.confirm_clean or confirm_clean
end

---@brief Loads the json lockfile needed for vim.pack functions
local function load_lockfile()
    local f = io.open(pack_lockfile, "r") -- Open
    if f then
        local content = f:read("*a") -- Read full file
        f:close()
        if content and #content > 0 then -- check for nil or false and length <= 0
            local ok, decoded = pcall(vim.fn.json_decode, content)
            if ok and type(decoded) == "table" then
                pack_lockfile_content = decoded
            else
                vim.notify("Failed to decode lockfile", vim.log.levels.ERROR)
                return false
            end
        else
            vim.notify("Lockfile empty", vim.log.levels.ERROR)
            return false
        end
    else
        vim.notify("Failed to open lockfile", vim.log.levels.ERROR)
        return false
    end
    return true
end

---@brief loads the plugin install list, installs the plugins and configures them based on user configs
---@param plugin_list table the list of plugins to install and configure (must match the filename of the config file)
---@param plugin_dir string? the directory to check for plugins if not the default or user configured default path
function M.load(plugin_list, plugin_dir) plugin_dir = plugin_dir or default_plugin_dir
    for _, plugin in ipairs(plugin_list) do
        -- Try to load the module
        local ok, module = pcall(require, plugin_dir .. "." .. plugin)
        if not ok then
            vim.notify("Failed to Locate Module: " .. plugin, vim.log.levels.ERROR)
        else
            -- Construct the git link list
            if not module.link then
                vim.notify("Missing Field: link", vim.log.levels.ERROR)
            elseif type(module.link) == "string" then
                table.insert(pack_list, remote_url .. module.link)
                plugin_name_list[string.match(module.link, "%/(.*)$")] = 'installed'
            else
                -- Sometimes a branch is specified (pass a table instead)
                table.insert(pack_list, { src = remote_url .. module.link.src, version = module.link.version })
                plugin_name_list[string.match(module.link.src, "%/(.*)$")] = 'installed'
            end
            -- Construct the Config list
            if not module.config then
                if type(module.config) ~= "boolean" then -- Plugins with no config are denoted "config = false"
                    vim.notify("No config for module: " .. plugin, vim.log.levels.ERROR)
                end
                table.insert(config_list, false) -- We still need an entry in the table to keep them the same size
            else
                if type(module.config) == "boolean" then -- This only happens if passed "config == true"
                    vim.notify("Config cannot have value 'true'. Use `config = false` " ..
                                "for plugins which do not call `setup()` or use `config = function()`",
                                vim.log.levels.ERROR)
                    table.insert(config_list, false)
                else
                    table.insert(config_list, module.config)
                end
            end
        end
    end
    -- Install
    vim.pack.add(pack_list)
    -- Check for update
    if always_update then
        M.update({})
    end
    -- Configure
    for i, plugin_config in ipairs(config_list) do
        if not plugin_config then
            -- Do nothing
        else
            if type(plugin_config) == "table" then
                vim.notify("Error loading config for: " .. plugin_list[i] .. "Config must be a function",
                    vim.log.levels.ERROR)
            else
                plugin_config()
                -- vim.notify(plugin_list[i] .. ": Config Loaded Successfully", vim.log.levels.INFO)
            end
        end
    end
end

---@brief Update installed plugins
---@param update_list table? the list of plugins to update (optional, does all otherwise)
function M.update(update_list)
    if update_list then
        vim.pack.update(update_list, { force = confirm_update })
    else
        vim.pack.update({ force = confirm_update })
    end
end

---@brief Delete the Unwanted Plugins (installed but not in list)
---@param ignore_list table? list of plugins to ignore when cleaning (optional)
function M.clean(ignore_list)
    if ignore_list then
        for _, name in ipairs(ignore_list) do
            plugin_name_list[name] = "ignore"
        end
    end
    local user_input = 'y'
    if not confirm_clean then user_input = 'Y' end -- If the confirm_clean option is false, clean all
    if load_lockfile() then
        for name, _ in pairs(pack_lockfile_content.plugins) do
            if not plugin_name_list[name] and  plugin_name_list[name] ~= "ignore" then
                if not user_input:match("^[YN]") then
                    vim.notify("Plugin: " .. name .. " Installed but not in pack list. Clean?", vim.log.levels.WARNING)
                    user_input = vim.fn.input("Clean " .. name .."? ([y]es|[n]o|[Y]es to all|[N]o to all):")
                    user_input = user_input:match("^[yYnN]")
                end
                -- Clean if yes or Yes
                if user_input:match("^[yY]") then vim.pack.del({ name }) end
            end
        end
    end
end

--- CREATE COMMANDS FOR MANUAL UPDATE ---
vim.api.nvim_create_user_command("SimplugUpdate", function(opts)
    if opts.args == "all" then M.update({})
    else M.update({ opts.args }) end
end, { nargs = 1 })

return M
