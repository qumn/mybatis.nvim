local M = {}

local defaults = {
	root_markers = { ".git", "pom.xml", "build.gradle", "settings.gradle" },
	mapper_tags = { "select", "insert", "update", "delete", "sql", "resultMap" },
	search = {
		exclude_dirnames = { "target", "build" },
	},
	mapper = {
		filetypes = { "java", "xml" },
		filename_patterns = { "Mapper%.java$", "Mapper%.xml$" },
	},
	fallback = {
		prefer_lsp = true,
	},
}

local config = vim.deepcopy(defaults)

function M.get()
	return config
end

function M.set(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	return config
end

return M
