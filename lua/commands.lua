local M = {}
--- CREATE USER COMMANDS FOR MANUAL USAGE ---

---@brief   registers the user commands and autocommands for Simplug
---@param   registry table<string, SimplugRegistryEntry>
---@param   simplug_update function
---@param   simplug_load function
function M.register(registry, simplug_update, simplug_load)

    if not registry and not simplug_update and not simplug_load and next(registry) then
        vim.notify("Failed to generate command completions, invalid arg to simplug.resister",
            vim.log.levels.ERROR)
        return M
    end

    local completion_generation = function(arg_lead, cmd_line, cursor_pos)
        _ = cmd_line
        _ = cursor_pos

        ---@type string[]
        local completions = {}

        ---@type string, SimplugRegistryEntry
        for name, _ in pairs(registry) do
            table.insert(completions, name)
        end

        return vim.tbl_filter(function(choice)
            return vim.startswith(choice, arg_lead)
        end, completions)
    end

    vim.api.nvim_create_user_command("SimplugLoad", function(opts)
        if opts.bang then
            local dir = table.remove(opts.fargs, 1)
            if type(dir) ~= "string" then
                vim.notify("Error updating plugin: expected 'string' as argument 1", vim.log.levels.ERROR)
                return
            end
            simplug_load(opts.fargs, true, dir)
            return
        else
            simplug_load(opts.fargs, true)
        end
    end, {
        bang = true,
        nargs = '+',
        complete = completion_generation,
        desc = "Loads the given plugins, bang: update plugins from dir (arg 1)"
    })

    vim.api.nvim_create_user_command("SimplugUpdate", function(opts)
        if not opts.count then return end
        simplug_update( opts.fargs )
    end, {
        nargs = '*',
        complete = completion_generation,
        desc = "Updates the given plugins or all if empty"
    })
end

return M
