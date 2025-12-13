local fs = require("mybatis.util.fs")
local xml = require("mybatis.util.xml")

local M = {}

local function normalize_java_type(value)
	local trimmed = vim.trim(value)
	trimmed = trimmed:gsub("%s+", "")
	trimmed = trimmed:gsub("%[%]$", "")
	trimmed = trimmed:match("^[^<]+") or trimmed
	return vim.trim(trimmed)
end

local function java_type_name(fqn)
	local last = fqn:match("([%w_$]+)$") or fqn
	return last:match("([^$]+)$") or last
end

local function extract_attr_positions(line, attr)
	if not line then
		return nil
	end
	local s, e, value = line:find(attr .. '%s*=%s*"([^"]+)"')
	if not s then
		s, e, value = line:find(attr .. "%s*=%s*'([^']+)'")
	end
	if not s then
		return nil
	end
	return s, e, value
end

local function extract_attr(line, attr)
	local _, _, value = extract_attr_positions(line, attr)
	return value
end

local function parse_attr_value(line, attr, cursor_col)
	local s, e, value = extract_attr_positions(line, attr)
	if not s then
		return nil
	end
	if cursor_col + 1 < s or cursor_col + 1 > e then
		return nil
	end
	return value
end

local function find_result_map_type(start_line, lines)
	for lnum = start_line, 1, -1 do
		local line = lines[lnum]
		if line and line:match("<%s*resultMap") then
			local attr = extract_attr(line, "type")
			if attr then
				return attr
			end
		end
	end
	return nil
end

local function parse_include_refid(line)
	return line:match('<include[^>]-refid%s*=%s*"([^"]+)"') or line:match("<include[^>]-refid%s*=%s*'([^']+)'")
end

local function parse_result_map_ref(line, cursor_col)
	return parse_attr_value(line, "resultMap", cursor_col)
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

		local cursor_col = cursor[2]
		local result_map = parse_result_map_ref(cur_text, cursor_col)
		if result_map then
			return {
				type = "resultMap_ref",
				file = file,
				lines = lines,
				result_map = result_map,
			}
		end

		local result_type = parse_attr_value(cur_text, "resultType", cursor_col)
		if result_type then
			local fqn = normalize_java_type(result_type)
			return {
				type = "java_type",
				file = file,
				dir = start_dir,
				fqn = fqn,
				name = java_type_name(fqn),
			}
		end

		if cur_text:match("<%s*resultMap%f[%W]") then
			local type_attr = parse_attr_value(cur_text, "type", cursor_col)
			if type_attr then
				local fqn = normalize_java_type(type_attr)
				return {
					type = "java_type",
					file = file,
					dir = start_dir,
					fqn = fqn,
					name = java_type_name(fqn),
				}
			end
		end
	end

	local property = nil
	local property_line = nil
	local cursor_col = cursor[2]
	local line = cur_text
	if line then
		property = parse_attr_value(line, "property", cursor_col)
		if property then
			property_line = find_result_map_type(cursor[1], lines)
		end
	end

	if property and property_line then
		local fqn = normalize_java_type(property_line)
		return {
			type = "result_property",
			file = file,
			dir = start_dir,
			fqn = fqn,
			property = property,
		}
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
