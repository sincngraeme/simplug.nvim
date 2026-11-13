---@diagnostic disable: undefined-global vim
---
---@class Simplug
local M = {}

local remote_url = "https://github.com/"

---@alias SimplugSpec { 
---origin: string|vim.pack.Spec,     --- link: link to git repo containing plugin
---config: function|nil,        --- config: function to run at config
---}

---@alias SimplugRegistryEntry {
---spec: SimplugSpec,
---installed: boolean,
---status: "loaded" | "loading" | "unloaded",
---}

---@alias SimplugConfig {
---plugin_dir: string,          --- plugin_dir: location to load plugin configs from (can also be passed to the load function)
---pack_lockfile: string,       --- pack_lockfile: location of the lockfile if not in the default location
---always_update: boolean,      --- always_update: whether or not to always run pack.update with load
---confirm_update: boolean,     --- confirm_update: whether or not to ask the user for confirmation when updating
---confirm_clean: boolean,      --- confirm_clean: whether or not to ask the user for confirmations when cleaning
---}

---@type string[]
local plugin_name_list = {}

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

---@type table<string, SimplugRegistryEntry>
local plugin_registry = {}

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

    ---@type vim.pack.Spec[]
    local plugin_spec_list = {}


    if type(plug_dir) ~= "string" then
        vim.notify("Invalid type for plugin directory: " .. type(plug_dir), vim.log.levels.ERROR)
        return
    end

    if type(plug_list) ~= "table" then
        vim.notify("Invalid type for plugin list: " .. type(plug_list), vim.log.levels.ERROR)
        return
    end

    for _, plugin in ipairs(plug_list) do

        if type(plugin) ~= "string" then
            vim.notify("Invalid type for plugin entry: " .. type(plugin), vim.log.levels.ERROR)
            goto continue
        end

        -- Skip if its spec can't be found
        ---@type boolean, SimplugSpec
        local ok, spec = pcall(require, plug_dir .. "." .. plugin)
        if not ok then
            vim.notify("Failed to Locate Module: " .. plugin, vim.log.levels.ERROR)
            goto continue
        end

        -- Skip if the origin is not a string or vim.pack.Spec
        local origin = spec.origin

        if type(origin) == "string" then
            spec.origin = { src = origin }
        elseif type(origin) == "table" then
            -- if no name was supplied, then use the repo url 
            -- (vim.pack.add does this but we need the field too)
            if not spec.origin.name then
                spec.origin.name = spec.origin.name or string.match(spec.origin.src, "%/(.*)$")
            end
        else
            vim.notify(
                "Error in config for plugin " .. plugin .. ": expected string|vim.pack.Spec",
                vim.log.levels.ERROR
            )
            goto continue
        end

        -- check if there is already an entry
        ---@type SimplugRegistryEntry
        local existing_entry = plugin_registry[plugin]
        if existing_entry then
            if existing_entry.installed then
                goto continue -- TOOD: should we update config?
            end
        end

        -- commit the changes to the registry
        plugin_registry[plugin] = { spec = spec, installed = true, status = "loading" }
        table.insert(plugin_name_list, plugin)
        table.insert(plugin_spec_list, spec.origin)

        :: continue ::
    end

    -- Install
    vim.pack.add(plugin_spec_list)

    -- Configure
    ---@type integer, string
    for _, name in ipairs(plugin_name_list) do
        if not name then
            -- Do nothing
        else
            local entry = plugin_registry[name]
            if type(entry.spec.config) == "function"
            or type(entry.spec.config) == "nil" then
                if entry.spec.config and not entry.spec.lazy then entry.spec.config() end
                vim.notify(name .. ": Config Loaded Successfully", vim.log.levels.INFO)
            else
                vim.notify("Error loading config for: " .. name .. " - config must be a function or nil",
                vim.log.levels.ERROR)
            end
        end
    end
end

---@brief Update installed plugins
---@param update_list string[]? the list of plugins to update (optional, does all otherwise)
function M.update(update_list)
    if type(update_list) == "table" and next(update_list) ~= nil then
        vim.pack.update(update_list, { force = not config.confirm_update })
    else
        vim.pack.update(nil, { force = not config.confirm_update })
    end
end

---@brief Delete the Unwanted Plugins (installed but not in list)
---@param ignore_list string[]? list of plugins to ignore when cleaning (optional)
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
    if not config.confirm_clean then user_input = 'Y' end


    if lockfile.load(config.pack_lockfile) then
        vim.notify("Error loading " .. config.pack_lockfile, vim.log.levels.ERROR)
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
