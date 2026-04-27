local M = {}

--- calls `vim.api.nvim_buf_get_lines()` but tries to load buffer first
--- @param bufnr integer
--- @param row integer (zero-indexed)
--- @return string?
function M.buf_get_line(bufnr, row)
  bufnr = vim._resolve_bufnr(bufnr)
  vim.fn.bufload(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
end

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
  local line = M.buf_get_line(bufnr, row)
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

--- converts LSP Position encoding to vim row and col indexing
---
--- @param bufnr number
--- @param lsp_pos lsp.Position
--- @param position_encoding 'utf-8'|'utf-16'|'utf-32'
--- @return [integer, integer] (row, col) tuple
function M.resolve_lsp_pos(bufnr, lsp_pos, position_encoding)
  local row = lsp_pos.line
  local col = lsp_pos.character
  if col > 0 then
    local line = M.buf_get_line(bufnr, row) or ""
    col = vim.str_byteindex(line, position_encoding, col, false)
  end
  return {
    row,
    col,
  }
end

return M
