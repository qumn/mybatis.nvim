if vim.g.loaded_mybatis_nvim then
	return
end
vim.g.loaded_mybatis_nvim = true

require("mybatis").setup()
