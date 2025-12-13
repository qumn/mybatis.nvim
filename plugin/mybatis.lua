if vim.g.loaded_mybatis_nvim then
	return
end
vim.g.loaded_mybatis_nvim = true

local mybatis = require("mybatis")

vim.api.nvim_create_user_command("MybatisJump", function()
	mybatis.jump()
end, { desc = "Jump between MyBatis interface and XML" })

local augroup = vim.api.nvim_create_augroup("MybatisNvim", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "xml" },
	callback = function(args)
		local name = vim.api.nvim_buf_get_name(args.buf)
		if not name:match("Mapper%.java$") and not name:match("Mapper%.xml$") then
			return
		end

		vim.keymap.set("n", "gd", function()
			mybatis.jump_or_fallback()
		end, { buffer = args.buf, desc = "MyBatis jump or LSP definition" })
	end,
})
