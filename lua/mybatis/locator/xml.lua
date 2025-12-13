local fs = require("mybatis.util.fs")
local xml = require("mybatis.util.xml")

local M = {}

local function read_xml_mappings(xml_path, expected_namespace, method, tags)
	local lines = fs.read_file_lines(xml_path)
	if not lines then
		return {}
	end

	if expected_namespace then
		local ns = xml.extract_namespace(lines)
		if ns ~= expected_namespace then
			return {}
		end
	end

	local hits = xml.find_id_hits(lines, method, tags)
	for _, hit in ipairs(hits) do
		hit.path = xml_path
	end
	return hits
end

function M.collect(ctx, cfg)
	local root = fs.find_project_root(ctx.dir, cfg.root_markers)
	local xml_name = ctx.class .. ".xml"
	local xml_files = fs.find_files_by_name(root, xml_name)

	local all_hits = {}
	for _, path in ipairs(xml_files) do
		local hits = read_xml_mappings(path, ctx.fqn, ctx.method, cfg.mapper_tags)
		for _, hit in ipairs(hits) do
			table.insert(all_hits, hit)
		end
	end
	return all_hits
end

function M.find_local_defs(lines, file, tags, target_id)
	local hits = {}
	for i, line in ipairs(lines) do
		for _, tag in ipairs(tags) do
			local pat1 = "<" .. tag .. '[^>]-id%s*=%s*"' .. vim.pesc(target_id) .. '"'
			local pat2 = "<" .. tag .. "[^>]-id%s*=%s*'" .. vim.pesc(target_id) .. "'"
			local pos = line:find(pat1) or line:find(pat2)
			if pos then
				table.insert(hits, { path = file, lnum = i, col = pos, line = line })
				break
			end
		end
	end
	return hits
end

return M
