local M = {}

function M.current_file(bufnr)
	return vim.api.nvim_buf_get_name(bufnr or 0)
end

local function is_abs_path(path)
	if not path or path == "" then
		return false
	end
	if path:sub(1, 1) == "/" then
		return true
	end
	if path:match("^%a:[/\\]") then
		return true
	end
	if path:sub(1, 2) == "\\\\" then
		return true
	end
	return false
end

local function path_has_dirname(path, dirname)
	if not path or path == "" or not dirname or dirname == "" then
		return false
	end
	local normalized = path:gsub("\\", "/")
	normalized = "/" .. normalized .. "/"
	local needle = "/" .. dirname .. "/"
	return normalized:find(needle, 1, true) ~= nil
end

local function should_exclude(path, opts)
	local excludes = opts and opts.exclude_dirnames or nil
	if not excludes or #excludes == 0 then
		return false
	end
	for _, dirname in ipairs(excludes) do
		if path_has_dirname(path, dirname) then
			return true
		end
	end
	return false
end

local function system_lines(args, cwd)
	if vim.system then
		local res = vim.system(args, { cwd = cwd, text = true }):wait()
		if not res or res.code ~= 0 then
			return nil
		end
		local out = res.stdout or ""
		if out == "" then
			return {}
		end
		return vim.split(out, "\n", { trimempty = true })
	end

	local escaped = {}
	for _, a in ipairs(args) do
		table.insert(escaped, vim.fn.shellescape(a))
	end
	local cmd = table.concat(escaped, " ")
	if cwd and cwd ~= "" then
		cmd = "cd " .. vim.fn.shellescape(cwd) .. " && " .. cmd
	end
	local lines = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return lines
end

function M.read_file_lines(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	return lines
end

function M.find_project_root(start_dir, markers)
	local root = vim.fs.find(markers, { upward = true, path = start_dir })[1]
	if root then
		return vim.fs.dirname(root)
	end

	local uv = vim.uv or vim.loop
	return uv.cwd()
end

function M.find_files_by_name(root, name, opts)
	if not root or root == "" or not name or name == "" then
		return {}
	end

	local results

	if vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1 then
		local fd_bin = vim.fn.executable("fd") == 1 and "fd" or "fdfind"
		local args = { fd_bin, "--type", "f", "--color", "never", "--hidden", "--follow" }
		local excludes = opts and opts.exclude_dirnames or nil
		if excludes then
			for _, dirname in ipairs(excludes) do
				if dirname and dirname ~= "" then
					table.insert(args, "--exclude")
					table.insert(args, dirname)
				end
			end
		end
		table.insert(args, "--fixed-strings")
		table.insert(args, name)
		table.insert(args, ".")
		results = system_lines(args, root)
	end

	if not results and vim.fn.executable("rg") == 1 then
		local args = { "rg", "--files", "--color", "never", "--hidden", "--follow", "--no-messages", "-g", name }
		local excludes = opts and opts.exclude_dirnames or nil
		if excludes then
			for _, dirname in ipairs(excludes) do
				if dirname and dirname ~= "" then
					table.insert(args, "-g")
					table.insert(args, "!" .. dirname .. "/**")
				end
			end
		end
		results = system_lines(args, root)
	end

	if not results then
		results = vim.fs.find(name, { path = root, type = "file" }) or {}
	end

	local filtered = {}
	for _, p in ipairs(results) do
		local path = p
		if not is_abs_path(path) then
			path = vim.fs.joinpath(root, path)
		end
		if vim.fs.basename(path) == name and not should_exclude(path, opts) then
			table.insert(filtered, path)
		end
	end

	return filtered
end

return M
