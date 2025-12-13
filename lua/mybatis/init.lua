local config = require("mybatis.config")
local java_context = require("mybatis.context.java")
local xml_context = require("mybatis.context.xml")
local java_locator = require("mybatis.locator.java")
local xml_locator = require("mybatis.locator.xml")
local ui = require("mybatis.ui")

local M = {}

local function matches_any(name, patterns)
	for _, pat in ipairs(patterns) do
		if name:match(pat) then
			return true
		end
	end
	return false
end

function M.is_mapper_file(bufnr)
	local cfg = config.get()
	bufnr = bufnr or 0

	local mapper = cfg.mapper or {}
	local filetypes = mapper.filetypes or {}
	local patterns = mapper.filename_patterns or {}

	if #filetypes > 0 then
		local ft = vim.bo[bufnr].filetype
		if ft == "" then
			return false
		end
		local ok = false
		for _, allowed in ipairs(filetypes) do
			if ft == allowed then
				ok = true
				break
			end
		end
		if not ok then
			return false
		end
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return false
	end

	if #patterns == 0 then
		return true
	end

	return matches_any(name, patterns)
end

local function has_lsp_clients(bufnr)
	if not (vim.lsp and vim.lsp.get_clients) then
		return false
	end

	return #vim.lsp.get_clients({ bufnr = bufnr }) > 0
end

local function fallback_definition(cfg)
	if cfg.fallback and cfg.fallback.prefer_lsp and has_lsp_clients(0) then
		vim.lsp.buf.definition()
		return
	end
	vim.cmd("normal! gd")
end

local function resolve_current_jump(cfg)
	local ft = vim.bo.filetype

	if ft == "java" then
		local ctx = java_context.from_current()
		if not ctx then
			return nil, nil, "java_context"
		end
		local hits = xml_locator.collect(ctx, cfg)
		return hits, ("MyBatis XML for %s#%s"):format(ctx.fqn, ctx.method), nil
	end

	if ft == "xml" then
		local ctx = xml_context.from_current(cfg.mapper_tags)
		if not ctx then
			return nil, nil, "xml_context"
		end

		if ctx.type == "include" then
			local hits = xml_locator.find_local_defs(ctx.lines, ctx.file, { "sql" }, ctx.refid)
			return hits, ('MyBatis <sql> for refid "%s"'):format(ctx.refid), nil
		end

		if ctx.type == "resultMap_ref" then
			local hits = xml_locator.find_local_defs(ctx.lines, ctx.file, { "resultMap" }, ctx.result_map)
			return hits, ('MyBatis <resultMap> for "%s"'):format(ctx.result_map), nil
		end

		local hits = java_locator.collect(ctx, cfg)
		return hits, ("MyBatis Java for %s#%s"):format(ctx.namespace, ctx.method), nil
	end

	return nil, nil, "unsupported_filetype"
end

function M.jump()
	local cfg = config.get()
	local hits, title, err = resolve_current_jump(cfg)

	if err == "unsupported_filetype" then
		vim.notify("mybatis.nvim: Jumping is only supported in Java and XML files", vim.log.levels.WARN)
		return
	end

	if err == "java_context" then
		vim.notify("mybatis.nvim: Failed to resolve current Java method", vim.log.levels.WARN)
		return
	end

	if err == "xml_context" then
		vim.notify("mybatis.nvim: Failed to resolve current XML mapping", vim.log.levels.WARN)
		return
	end

	ui.handle_results(hits, title)
end

function M.jump_or_fallback()
	local cfg = config.get()
	local hits, title = resolve_current_jump(cfg)
	if hits and #hits > 0 then
		ui.handle_results(hits, title)
		return
	end
	fallback_definition(cfg)
end

function M.setup(opts)
	config.set(opts)
	vim.api.nvim_create_user_command("MybatisJump", function()
		require("mybatis").jump()
	end, { desc = "Jump between MyBatis interface and XML" })
end

return M
