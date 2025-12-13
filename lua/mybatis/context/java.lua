local fs = require("mybatis.util.fs")
local java = require("mybatis.util.java")

local M = {}

function M.from_current()
	local buf = 0
	local file = fs.current_file(buf)
	if file == "" then
		return nil
	end

	local start_dir = vim.fs.dirname(file)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local pkg, class = java.extract_package_and_class(lines)
	if not class then
		return nil
	end

	local fqn = pkg and (pkg .. "." .. class) or class
	local cursor = vim.api.nvim_win_get_cursor(0)
	local method = java.find_nearest_method(lines, cursor[1])
	if not method then
		return nil
	end

	return {
		file = file,
		dir = start_dir,
		fqn = fqn,
		class = class,
		method = method,
	}
end

return M
