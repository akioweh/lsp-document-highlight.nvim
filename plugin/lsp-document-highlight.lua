if vim.g.loaded_lsp_document_highlight then
  return
end
vim.g.loaded_lsp_document_highlight = true

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePre" }, {
  callback = function()
    require("lsp-document-highlight").init()
  end,
  once = true,
})
