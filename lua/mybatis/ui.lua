local M = {}

local function open_location(hit)
	vim.cmd.edit(vim.fn.fnameescape(hit.path))
	vim.api.nvim_win_set_cursor(0, { hit.lnum, math.max(0, hit.col - 1) })
end

local function to_qf_items(hits)
	local items = {}
	for _, hit in ipairs(hits) do
		table.insert(items, {
			filename = hit.path,
			lnum = hit.lnum,
			col = hit.col,
			text = hit.line,
		})
	end
	return items
end

function M.handle_results(hits, title)
	if #hits == 0 then
		vim.notify("mybatis.nvim: No matches found", vim.log.levels.INFO)
	elseif #hits == 1 then
		open_location(hits[1])
	else
		vim.fn.setqflist({}, " ", {
			title = title,
			items = to_qf_items(hits),
		})
		vim.cmd.copen()
	end
end

return M
