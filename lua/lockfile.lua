---@diagnostic disable: undefined-global vim

local M = {}

M.content = {}

---@brief   load the lockfile contents
---@param file string
---@return boolean  --- true on success
function M.load(file)
    local f = io.open(file, "r") -- Open
    if not f then
        vim.notify("Failed to open lockfile", vim.log.levels.ERROR)
        return false
    end

    local content = f:read("*a") -- Read full file
    f:close()

    if not content or #content <= 0 then -- check for nil or false and length <= 0
        vim.notify("Lockfile empty", vim.log.levels.ERROR)
        return false
    end

    local ok, decoded = pcall(vim.fn.json_decode, content)
    if not ok or type(decoded) ~= "table" then
        vim.notify("Failed to decode lockfile", vim.log.levels.ERROR)
    return false
    end

    M.lockfile_content = decoded

    return true
end

return M
