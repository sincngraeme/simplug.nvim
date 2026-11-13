local M = {}
--- CREATE USER COMMANDS FOR MANUAL USAGE ---

---@module 'simplug'
local simplug = require("simplug")

---@brief   registers the user commands and autocommands for Simplug
---@param   names string[]
function M.register(names)

    local completion_generation = function(arg_lead, cmd_line, cursor_pos)
        _ = cmd_line
        _ = cursor_pos

        local command_line_completions = {}

        for key, _ in pairs(names) do
            table.insert(command_line_completions, key)
        end

        return vim.tbl_filter(function(choice)
            return vim.startswith(choice, arg_lead)
        end, command_line_completions)
    end

    vim.api.nvim_create_user_command("SimplugLoad", function(opts)
        if opts.bang then
            local dir = table.remove(opts.fargs, 1)
            if type(dir) ~= "string" then
                vim.notify("Error updating plugin: expected 'string' as argument 1", vim.log.levels.ERROR)
                return
            end
            simplug.load(opts.fargs, dir)
            return
        end
        simplug.load(opts.fargs)
    end, { bang = true, nargs = '+', complete = completion_generation })

    vim.api.nvim_create_user_command("SimplugUpdate", function(opts)
        if not opts.count then return end
        simplug.update( opts.fargs )
    end, { nargs = '*', complete = completion_generation })
end

return M
