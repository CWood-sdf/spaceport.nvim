local M = {}

local opts = {
    ignoreDirs = {},
    replaceHome = true,
}
M.setup = function(_opts)
    for k, v in pairs(_opts) do
        if not opts[k] then
            error("Invalid option: " .. k)
        end
        opts[k] = v
    end
end

M._getIgnoreDirs = function()
    return opts.ignoreDirs
end


M._swapHomeWithTilde = function(path)
    if opts.replaceHome then
        if jit.os == "Windows" then
            return path:gsub(os.getenv("USERPROFILE"), "~")
        end
        return path:gsub(os.getenv("HOME"), "~")
    end
    return path
end

M._fixDir = function(path)
    local ret = M._swapHomeWithTilde(path)
    for _, dir in ipairs(opts.ignoreDirs) do
        local ok, _ = pcall(ipairs, dir)
        if ok then
            ret = ret:gsub(dir[1], dir[2])
            return ret
        else
            ret = ret:gsub(dir, "")
        end
    end
    return ret
end

return M
