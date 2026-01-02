local M = {}

--- gets cursor position for a given buffer
--- @param bufnr number
--- @return [integer, integer] (row, col) tuple
function M.get_cursor(bufnr)
	local win = vim.fn.bufwinid(bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr)
	if win ~= -1 then
		return vim.api.nvim_win_get_cursor(win)
	end
	return vim.api.nvim_buf_get_mark(bufnr, '"')
end

--- just like `vim.lsp.util.make_position_param`
--- but is buffer-based insetad of window-based
--- @param bufnr number
--- @param position_encoding 'utf-8'|'utf-16'|'utf-32'
function M.make_position_param(bufnr, position_encoding)
	local row, col = unpack(M.get_cursor(bufnr))
	if row == 0 and col == 0 then
		return { line = 0, character = 0 }
	end
	row = row - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
	if not line then
		return { line = 0, character = 0 }
	end
	col = vim.str_utfindex(line, position_encoding, col, false)
	return { line = row, character = col }
end

--- just like `vim.lsp.util.make_position_params`
--- but is buffer-based insetad of window-based
--- @param bufnr number
--- @param position_encoding 'utf-8'|'utf-16'|'utf-32'
function M.make_position_params(bufnr, position_encoding)
	return {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = M.make_position_param(bufnr, position_encoding),
	}
end

return M
