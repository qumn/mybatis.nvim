local M = {}

local sep = package.config:sub(1, 1)

local mapper_tags = {
	"select",
	"insert",
	"update",
	"delete",
	"sql",
	"resultMap",
}

local function get_current_file()
	return vim.api.nvim_buf_get_name(0)
end

local function read_file_lines(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	return lines
end

local function find_project_root(start_dir)
	local markers = { ".git", "pom.xml", "build.gradle", "settings.gradle" }
	local root = vim.fs.find(markers, { upward = true, path = start_dir })[1]
	if root then
		return vim.fs.dirname(root)
	end
	return vim.loop.cwd()
end

local function find_files_by_name(root, name)
	local results = vim.fs.find(name, { path = root, type = "file" })
	return results or {}
end

local function extract_package_and_class(lines)
	local pkg
	local class
	for _, line in ipairs(lines) do
		if not pkg then
			local m = line:match("^%s*package%s+([%w%._]+)%s*;")
			if m then
				pkg = m
			end
		end
		if not class then
			local m = line:match("^%s*interface%s+([%w_]+)") or line:match("^%s*public%s+interface%s+([%w_]+)")
			if m then
				class = m
			end
		end
		if pkg and class then
			break
		end
	end
	return pkg, class
end

local function get_java_context()
	local buf = 0
	local file = get_current_file()
	if file == "" then
		return nil
	end
	local start_dir = vim.fs.dirname(file)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local pkg, class = extract_package_and_class(lines)
	if not class then
		return nil
	end
	local fqn
	if pkg then
		fqn = pkg .. "." .. class
	else
		fqn = class
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_line = cursor[1]
	local method
	for lnum = cur_line, 1, -1 do
		local line = lines[lnum]
		if line then
			local name = line:match("%f[%w_]([%w_]+)%s*%(")
			if name then
				local head = line:sub(1, line:find(name, 1, true) - 1)
				if head:match("%f[%a](public|protected|private|default)%f[^%a]") or head:match("%w") then
					method = name
					break
				end
			end
		end
	end

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

local function extract_namespace(lines)
	for _, line in ipairs(lines) do
		local ns = line:match('<mapper[^>]-namespace%s*=%s*"([^"]+)"')
			or line:match("<mapper[^>]-namespace%s*=%s*'([^']+)'")
		if ns then
			return ns
		end
	end
	return nil
end

local function find_id_in_xml(lines, method)
	local results = {}
	for i, line in ipairs(lines) do
		for _, tag in ipairs(mapper_tags) do
			local pat1 = "<" .. tag .. '[^>]-id%s*=%s*"' .. vim.pesc(method) .. '"'
			local pat2 = "<" .. tag .. "[^>]-id%s*=%s*'" .. vim.pesc(method) .. "'"
			local s = line:find(pat1)
			local e = line:find(pat2)
			local pos = s or e
			if pos then
				table.insert(results, { lnum = i, col = pos, line = line })
				break
			end
		end
	end
	return results
end

local function read_xml_mappings(xml_path, expected_namespace, method)
	local lines = read_file_lines(xml_path)
	if not lines then
		return {}
	end

	local ns = extract_namespace(lines)
	if expected_namespace and ns and ns ~= expected_namespace then
		return {}
	end

	local hits = find_id_in_xml(lines, method)
	for _, hit in ipairs(hits) do
		hit.path = xml_path
	end
	return hits
end

local function collect_xml_locations(ctx)
	local root = find_project_root(ctx.dir)
	local xml_name = ctx.class .. ".xml"
	local xml_files = find_files_by_name(root, xml_name)

	local all_hits = {}
	for _, path in ipairs(xml_files) do
		local hits = read_xml_mappings(path, ctx.fqn, ctx.method)
		for _, h in ipairs(hits) do
			table.insert(all_hits, h)
		end
	end
	return all_hits
end

local function get_xml_context()
	local buf = 0
	local file = get_current_file()
	if file == "" then
		return nil
	end
	local start_dir = vim.fs.dirname(file)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local namespace = extract_namespace(lines)
	if not namespace then
		return nil
	end
	local class = namespace:match("([%w_]+)$") or namespace

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_line = cursor[1]
	local method
	for lnum = cur_line, 1, -1 do
		local line = lines[lnum]
		if line then
			local id = line:match('id%s*=%s*"([%w_]+)"') or line:match("id%s*=%s*'([%w_]+)'")
			if id then
				method = id
				break
			end
		end
	end

	if not method then
		return nil
	end

	return {
		file = file,
		dir = start_dir,
		namespace = namespace,
		class = class,
		method = method,
	}
end

local function read_java_methods(java_path, expected_namespace, method)
	local lines = read_file_lines(java_path)
	if not lines then
		return {}
	end

	local pkg, class = extract_package_and_class(lines)
	if pkg and class and expected_namespace then
		local fqn = pkg .. "." .. class
		if fqn ~= expected_namespace then
			return {}
		end
	end

	local hits = {}
	for i, line in ipairs(lines) do
		local pos = line:find("%f[%w_]" .. vim.pesc(method) .. "%s*%(")
		if pos then
			table.insert(hits, { path = java_path, lnum = i, col = pos, line = line })
		end
	end
	return hits
end

local function collect_java_locations(ctx)
	local root = find_project_root(ctx.dir)
	local java_name = ctx.class .. ".java"
	local java_files = find_files_by_name(root, java_name)

	local all_hits = {}
	for _, path in ipairs(java_files) do
		local hits = read_java_methods(path, ctx.namespace, ctx.method)
		for _, h in ipairs(hits) do
			table.insert(all_hits, h)
		end
	end
	return all_hits
end

local function open_location(hit)
	vim.cmd.edit(vim.fn.fnameescape(hit.path))
	vim.api.nvim_win_set_cursor(0, { hit.lnum, math.max(0, hit.col - 1) })
end

local function to_qf_items(hits)
	local items = {}
	for _, hit in ipairs(hits) do
		table.insert(items, {
			filename = hit.path,
			lnum = hit.lnum,
			col = hit.col,
			text = hit.line,
		})
	end
	return items
end

local function handle_results(hits, title)
	if #hits == 0 then
		vim.notify("mybatis.nvim: 未找到匹配的映射", vim.log.levels.INFO)
	elseif #hits == 1 then
		open_location(hits[1])
	else
		vim.fn.setqflist({}, " ", {
			title = title,
			items = to_qf_items(hits),
		})
		vim.cmd.copen()
	end
end

function M.jump()
	local ft = vim.bo.filetype
	if ft == "java" then
		local ctx = get_java_context()
		if not ctx then
			vim.notify("mybatis.nvim: 无法解析当前 Java 方法", vim.log.levels.WARN)
			return
		end
		local hits = collect_xml_locations(ctx)
		handle_results(hits, "MyBatis XML for " .. ctx.fqn .. "#" .. ctx.method)
	elseif ft == "xml" then
		local ctx = get_xml_context()
		if not ctx then
			vim.notify("mybatis.nvim: 无法解析当前 XML 映射", vim.log.levels.WARN)
			return
		end
		local hits = collect_java_locations(ctx)
		handle_results(hits, "MyBatis Java for " .. ctx.namespace .. "#" .. ctx.method)
	else
		vim.notify("mybatis.nvim: 只支持在 Java 或 XML 文件中跳转", vim.log.levels.WARN)
	end
end

function M.jump_or_fallback()
	local ft = vim.bo.filetype

	if ft == "java" then
		local ctx = get_java_context()
		if ctx then
			local hits = collect_xml_locations(ctx)
			if hits and #hits > 0 then
				handle_results(hits, "MyBatis XML for " .. ctx.fqn .. "#" .. ctx.method)
				return
			end
		end
	elseif ft == "xml" then
		local ctx = get_xml_context()
		if ctx then
			local hits = collect_java_locations(ctx)
			if hits and #hits > 0 then
				handle_results(hits, "MyBatis Java for " .. ctx.namespace .. "#" .. ctx.method)
				return
			end
		end
	end

	vim.cmd("normal! gd")
end

function M.setup(_) end

return M
