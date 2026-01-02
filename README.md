# lsp-document-highlight

does `vim.lsp.buf.document_highlight()` for you in a fast way.  
assuming your lsp is not slow, the highlights will update instantaneously.

also supports navigating to prev/next references.

## Installation

consult your favorite plugin manager.

this plugin loads itself -- no need to call any setup function.  
the plugin is self-lazy-loading.

## Configuration

see [config.lua](lua/lsp-document-highlight/config.lua) for the defaults and [types.lua](lua/lsp-document-highlight/types.lua) for annotations
on what the keys mean.  
if you have lua_ls set up, you will also get autocompletion and
docs in your plugin config if you annotate your config table with
the `LDH.config` type.

Example setup with keymaps to navigate references (using `lazy.nvim`):

```lua
---@type LazySpec
return {
  {
    "akioweh/lsp-document-highlight.nvim",
    lazy = false,
    keys = {
      {
        "[[",
        function()
          require("lsp-document-highlight").jump(-vim.v.count1)
        end,
        desc = "Previous Reference",
      },
      {
        "]]",
        function()
          require("lsp-document-highlight").jump(vim.v.count1)
        end,
        desc = "Next Reference",
      },
    },
    ---@type LDH.config
    opts = {
      throttle = 50,
    },
  },
}
```
