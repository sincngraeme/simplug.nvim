local M = {}
--- CREATE USER COMMANDS FOR MANUAL USAGE ---

---@brief   registers the user commands and autocommands for Simplug
---@param   registry table<string, SimplugRegistryEntry>
---@param   update function
---@param   load function
function M.register(registry, update, load)

    if not registry and not update and not load and next(registry) then
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
	for _, value in pairs(registry) do
		if not value.spec or not value.spec.origin then
		    vim.notify("Failed to generate command completions: nil entry", vim.log.levels.ERROR)
		else
		    if type(value.spec.origin) == "string" then
			table.insert(completions, value.spec.origin)
		    elseif type(value.spec.origin) == "table" then
			table.insert(completions, value.spec.origin.name)
		    end
		    -- if it's somehow something else, just skip
		end
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
            load(opts.fargs, dir)
            return
        end
        load(opts.fargs)
    end, {
        bang = true,
        nargs = '+',
        complete = completion_generation,
        desc = "Loads the given plugins, bang: update plugins from dir (arg 1)"
    })

    vim.api.nvim_create_user_command("SimplugUpdate", function(opts)
        if not opts.count then return end
        update( opts.fargs )
    end, {
        nargs = '*',
        complete = completion_generation,
        desc = "Updates the given plugins or all if empty"
    })
end

return M
