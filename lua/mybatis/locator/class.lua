local fs = require("mybatis.util.fs")
local java = require("mybatis.util.java")

local M = {}

local function find_type_declaration(lines, target)
	local keywords = { "class", "interface", "enum", "record" }
	for i, line in ipairs(lines) do
		for _, kw in ipairs(keywords) do
			local pat = "%f[%a]" .. kw .. "%f[%A]%s+" .. vim.pesc(target) .. "%f[%W]"
			local pos = line:find(pat)
			if pos then
				return i, pos, line
			end
		end
	end
	return 1, 1, lines[1] or ""
end

local function matches_fqn(lines, expected_fqn)
	local pkg, class = java.extract_package_and_class(lines)
	if not class then
		return false
	end

	local fqn = pkg and (pkg .. "." .. class) or class
	if expected_fqn == fqn then
		return true
	end

	if expected_fqn:sub(1, #fqn + 1) == fqn .. "." then
		return true
	end

	if expected_fqn:sub(1, #fqn + 1) == fqn .. "$" then
		return true
	end

	return false
end

local function capitalize(str)
	return (str:gsub("^%l", string.upper))
end

local function find_property_position(lines, property)
	local pat = "%f[%w_]" .. vim.pesc(property) .. "%f[%W]"
	for i, line in ipairs(lines) do
		if line:find(pat) then
			if line:find(";") and not line:find("%(") then
				local col = line:find(pat)
				return i, col, line
			end
		end
	end
	local setter = "set" .. capitalize(property)
	local getter = "get" .. capitalize(property)
	for i, line in ipairs(lines) do
		local col = line:find("%f[%w_]" .. vim.pesc(setter) .. "%f[%W]")
		if col then
			return i, col, line
		end
		col = line:find("%f[%w_]" .. vim.pesc(getter) .. "%f[%W]")
		if col then
			return i, col, line
		end
	end
	return nil
end

local function ordered_base_names(expected_fqn, target_name)
	local base = target_name
	if base == "" then
		return {}
	end

	local out = { base }
	local last = expected_fqn:match("([%w_$]+)$") or expected_fqn
	local dollar = last:find("$", 1, true)
	if dollar and dollar > 1 then
		local outer = last:sub(1, dollar - 1)
		if outer ~= base then
			table.insert(out, outer)
		end
	end

	if expected_fqn:find("%.", 1, true) and not base:find("%$", 1, true) then
		local parent = expected_fqn:match("([%w_]+)%.[%w_$]+$")
		if parent and parent:match("^[A-Z]") and parent ~= base then
			table.insert(out, parent)
		end
	end

	return out
end

function M.collect(ctx, cfg)
	local expected_fqn = ctx.fqn
	if not expected_fqn or expected_fqn == "" then
		return {}
	end

	local root = fs.find_project_root(ctx.dir, cfg.root_markers)
	local target_name = ctx.name or (expected_fqn:match("([%w_$]+)$") or expected_fqn)
	local bases = ordered_base_names(expected_fqn, target_name)

	local hits = {}
	local seen = {}
	for _, base in ipairs(bases) do
		local filename = base .. ".java"
		for _, path in ipairs(fs.find_files_by_name(root, filename, cfg.search)) do
			if not seen[path] then
				seen[path] = true
				local lines = fs.read_file_lines(path)
				if lines and matches_fqn(lines, expected_fqn) then
					if ctx.property and ctx.property ~= "" then
						local lnum, col, text = find_property_position(lines, ctx.property)
						if lnum then
							table.insert(hits, { path = path, lnum = lnum, col = col, line = text })
						end
					else
						local lnum, col, text = find_type_declaration(lines, target_name)
						if lnum == 1 and base ~= target_name then
							lnum, col, text = find_type_declaration(lines, base)
						end
						table.insert(hits, { path = path, lnum = lnum, col = col, line = text })
					end
				end
			end
		end
		if #hits > 0 then
			break
		end
	end

	return hits
end

return M
