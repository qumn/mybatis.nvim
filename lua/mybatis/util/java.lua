local M = {}

function M.extract_package_and_class(lines)
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
			local m = line:match("%f[%a]interface%f[%A]%s+([%w_]+)")
				or line:match("%f[%a]class%f[%A]%s+([%w_]+)")
				or line:match("%f[%a]enum%f[%A]%s+([%w_]+)")
				or line:match("%f[%a]record%f[%A]%s+([%w_]+)")
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

function M.method_name_in_declaration(line)
	if not line or not line:find("%(") then
		return nil
	end

	if line:match("^%s*@") or line:match("^%s*//") or line:match("^%s*/%*") or line:match("^%s*%*") then
		return nil
	end

	if line:match("^%s*(if|for|while|switch|catch)%f[%W]") then
		return nil
	end

	local has_end = line:match("%)%s*;") or line:match("%)%s*{") or line:match("%)%s*throws%s+[%w_%.%,%s]+[;{]")
	if not has_end then
		return nil
	end

	return line:match("^%s*[%w_%.$<>%[%],%s%?%&]+%s+([%w_]+)%s*%(")
end

function M.find_nearest_method(lines, start_line)
	for lnum = start_line, 1, -1 do
		local name = M.method_name_in_declaration(lines[lnum])
		if name then
			return name
		end
	end
	return nil
end

return M
