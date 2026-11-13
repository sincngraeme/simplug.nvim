---@diagnostic disable: undefined-global vim
---
---@class Simplug
local M = {}

local remote_url = "https://github.com/"

---@alias SimplugSpec { 
---link: string,            --- link: link to git repo containing plugin
---config: function,        --- config: function to run at config
---}

---@alias SimplugConfig {
---plugin_dir: string,          --- plugin_dir: location to load plugin configs from (can also be passed to the load function)
---pack_lockfile: string,       --- pack_lockfile: location of the lockfile if not in the default location
---always_update: boolean,      --- always_update: whether or not to always run pack.update with load
---confirm_update: boolean,     --- confirm_update: whether or not to ask the user for confirmation when updating
---confirm_clean: boolean,      --- confirm_clean: whether or not to ask the user for confirmations when cleaning
---}

local pack_list = {}  -- absolute links for installations
local config_list = {} -- Configurations for each plugin
local plugin_name_list = {} -- The actual names of the plugins

---@type SimplugConfig
local default_config = {
    plugin_dir = "plugins",
    pack_lockfile = vim.fn.stdpath("config") .. "/nvim-pack-lock.json",
    always_update = false,
    confirm_update = true,
    confirm_clean = false
}

---@type SimplugConfig
local config = {}

---@type table<string, SimplugSpec>
local plugin_list = {}

---@brief   Setup function for the module
---@param   user_config SimplugConfig 
---@return  Simplug --- module instance
function M.setup(user_config)
    config.plugin_dir = user_config.plugin_dir or default_config.plugin_dir
    config.pack_lockfile = user_config.pack_lockfile or default_config.pack_lockfile
    config.always_update = user_config.always_update or default_config.always_update
    config.confirm_update = user_config.confirm_update or default_config.confirm_update
    config.confirm_clean = user_config.confirm_clean or default_config.confirm_clean

    ---@module 'commands'
    local cmds = require("commands")

    cmds.register(plugin_name_list, M.update, M.load)

    return M
end

---@brief Loads the json lockfile needed for vim.pack functions

---@brief loads the plugin install list, installs the plugins and configures them based on user configs
---@param plug_list table the list of plugins to install and configure (must match the filename of the config file)
---@param plug_dir string? the directory to check for plugins if not the default or user configured default path
function M.load(plug_list, plug_dir) plug_dir = plug_dir or config.plugin_dir
    for _, plugin in ipairs(plug_list) do
        -- Try to load the module
        local ok, module = pcall(require, plug_dir .. "." .. plugin)
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
    if config.always_update then
        M.update({})
    end
    -- Configure
    for i, plugin_config in ipairs(config_list) do
        if not plugin_config then
            -- Do nothing
        else
            if type(plugin_config) == "table" then
                vim.notify("Error loading config for: " .. plug_list[i] .. "Config must be a function",
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
    if type(update_list) == "table" and next(update_list) ~= nil then
        vim.pack.update(update_list, { force = not config.confirm_update })
    else
        vim.pack.update(nil, { force = not config.confirm_update })
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

    ---@module 'lockfile'
    local lockfile = require("lockfile")

    -- If the confirm_clean option is false, clean all
    local user_input = 'y'
    if not confirm_clean then user_input = 'Y' end


    if lockfile.load(config.pack_lockfile) then
        vim.notfiy("Error loading " .. config.pack_lockfile, vim.log.levels.ERROR)
        return
    end
    for name, _ in pairs(lockfile.content.plugins) do
        if not plugin_name_list[name] and plugin_name_list[name] ~= "ignore" and name ~= "simplug.nvim" then
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

return M
