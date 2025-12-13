local M = {}

function M.current_file(bufnr)
	return vim.api.nvim_buf_get_name(bufnr or 0)
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

function M.find_files_by_name(root, name)
	local results = vim.fs.find(name, { path = root, type = "file" })
	return results or {}
end

return M
