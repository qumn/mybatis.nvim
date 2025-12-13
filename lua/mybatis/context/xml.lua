local fs = require("mybatis.util.fs")
local xml = require("mybatis.util.xml")

local M = {}

local function parse_include_refid(line)
	return line:match('<include[^>]-refid%s*=%s*"([^"]+)"') or line:match("<include[^>]-refid%s*=%s*'([^']+)'")
end

local function parse_result_map_ref(line, cursor_col)
	local s, e, value = line:find('resultMap%s*=%s*"([^"]+)"')
	if not s then
		s, e, value = line:find("resultMap%s*=%s*'([^']+)'")
	end
	if not s then
		return nil
	end
	if cursor_col + 1 < s or cursor_col + 1 > e then
		return nil
	end
	return value
end

function M.from_current(tags)
	local buf = 0
	local file = fs.current_file(buf)
	if file == "" then
		return nil
	end

	local start_dir = vim.fs.dirname(file)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_line = cursor[1]
	local cur_text = lines[cur_line]
	if cur_text then
		local refid = parse_include_refid(cur_text)
		if refid then
			return {
				type = "include",
				file = file,
				lines = lines,
				refid = refid,
			}
		end

		local result_map = parse_result_map_ref(cur_text, cursor[2])
		if result_map then
			return {
				type = "resultMap_ref",
				file = file,
				lines = lines,
				result_map = result_map,
			}
		end
	end

	local namespace = xml.extract_namespace(lines)
	if not namespace then
		return nil
	end

	local class = namespace:match("([%w_]+)$") or namespace
	local method = xml.find_nearest_id(lines, cur_line, tags)
	if not method then
		return nil
	end

	return {
		type = "mapper",
		file = file,
		dir = start_dir,
		namespace = namespace,
		class = class,
		method = method,
	}
end

return M
