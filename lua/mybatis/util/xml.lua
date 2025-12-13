local M = {}

function M.extract_namespace(lines)
	for _, line in ipairs(lines) do
		local ns = line:match('<mapper[^>]-namespace%s*=%s*"([^"]+)"')
			or line:match("<mapper[^>]-namespace%s*=%s*'([^']+)'")
		if ns then
			return ns
		end
	end
	return nil
end

function M.find_id_hits(lines, target_id, tags)
	local results = {}
	for i, line in ipairs(lines) do
		for _, tag in ipairs(tags) do
			local pat1 = "<" .. tag .. '[^>]-id%s*=%s*"' .. vim.pesc(target_id) .. '"'
			local pat2 = "<" .. tag .. "[^>]-id%s*=%s*'" .. vim.pesc(target_id) .. "'"
			local pos = line:find(pat1) or line:find(pat2)
			if pos then
				table.insert(results, { lnum = i, col = pos, line = line })
				break
			end
		end
	end
	return results
end

function M.find_nearest_id(lines, start_line, tags)
	for lnum = start_line, 1, -1 do
		local line = lines[lnum]
		for _, tag in ipairs(tags) do
			local id = line:match("<" .. tag .. '[^>]-id%s*=%s*"([%w_]+)"')
				or line:match("<" .. tag .. "[^>]-id%s*=%s*'([%w_]+)'")
			if id then
				return id
			end
		end
	end
	return nil
end

return M
