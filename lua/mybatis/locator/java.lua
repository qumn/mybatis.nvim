local fs = require("mybatis.util.fs")
local java = require("mybatis.util.java")

local M = {}

local function read_java_methods(java_path, expected_namespace, method)
	local lines = fs.read_file_lines(java_path)
	if not lines then
		return {}
	end

	local pkg, class = java.extract_package_and_class(lines)
	if expected_namespace then
		if not class then
			return {}
		end
		local fqn = pkg and (pkg .. "." .. class) or class
		if fqn ~= expected_namespace then
			return {}
		end
	end

	local hits = {}
	for i, line in ipairs(lines) do
		if java.method_name_in_declaration(line) == method then
			local pos = line:find("%f[%w_]" .. vim.pesc(method) .. "%s*%(")
			if pos then
				table.insert(hits, { path = java_path, lnum = i, col = pos, line = line })
			end
		end
	end
	return hits
end

function M.collect(ctx, cfg)
	local root = fs.find_project_root(ctx.dir, cfg.root_markers)
	local java_name = ctx.class .. ".java"
	local java_files = fs.find_files_by_name(root, java_name, cfg.search)

	local all_hits = {}
	for _, path in ipairs(java_files) do
		local hits = read_java_methods(path, ctx.namespace, ctx.method)
		for _, hit in ipairs(hits) do
			table.insert(all_hits, hit)
		end
	end
	return all_hits
end

return M
