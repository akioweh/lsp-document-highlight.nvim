# lsp-document-highlight.nvim

*provides you with the power of the `textDocument.documentHighlight` LSP method in a speedy way*

> [!TIP]
> [`textDocument.documentHighlight`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_documentHighlight), aka.
> "cursor word highlighting" or "reference highlighting",
> is the UI feature where all references to the symbol under the cursor are shown using a highlight.

## why does this exist

- instantaneous\*, live updating unlike putting `vim.lsp.buf.document_highlight()` in an autocmd on `CursorHold`

- no performance issues (configurable lsp call throttling) unlike putting `vim.lsp.buf.document_highlight()` in an autocmd on `CursorMoved`

- no flickering (due to slow lsp) when moving within the same symbol unlike any autocmd solution or [`vim-illuminate`](https://github.com/RRethy/vim-illuminate)

- throttling instead of debouncing so updates trigger immediately when possible unlike [`snacks.nvim` words](https://github.com/folke/snacks.nvim/blob/main/docs/words.md)

- also supports navigating between references (see keymapping below).

\*: assuming your lsp is not being slow (\*cough\* \*cough\* `lua_ls`... i've heard typescript lsp is also slow but :shrug: not something i use)

## installation

consult your favorite plugin manager.

this plugin loads itself -- no need to call any setup function.\
this plugin is self-lazy-loading.
(although `setup()` currently triggers loading... but there's so little code anyway)

## configuration

see [config.lua](./lua/lsp-document-highlight/config.lua) for the defaults
and [types.lua](./lua/lsp-document-highlight/types.lua) for annotations on what the keys mean.\
if you have `lua_ls` set up, you can also enjoy autocompletion and
hover documentation in your plugin config
if you annotate the table with the `LDH.config` type.

## lua api

the module is called `lsp-document-highlight`.
require it to access all the public functions (see [the code](./lua/lsp-document-highlight.lua)).

the only thing of interest now is the `require("lsp-document-highlight").jump(count)` function:

> [!TIP]
> in a keymap, passing `vim.v.count1` into `jump` allows one to naturally use vim keycounts to jump multiple references at once.

```lua
--- jumps to the next count-th (or previous if negative) reference
--- @param count number
--- @return LDH.JumpResult|boolean result jump search count, or false when "unhandled"
function M.jump(count)
  -- ...
end
```

> [!NOTE]
> this function follows the behavior of built-in searches like `#` / `*`;
> wrapping behavior follows `vim.o.wrapscan`, search count is printed according to `vim.o.shortmess`, certain marks are set, etc.
>
> this means that such a config naturally "empowers" `#` / `*` with LSP info,
> and falls back to string matching when needed:
>
> ```lua
> vim.keymap.set("n", "#", function()
>   if not require("lsp-document-highlight").jump(-vim.v.count1) then
>     -- using raw feedkeys to avoid stacktrace being printed when Vim: E348 is thrown (when cursor on whitespace)
>     vim.api.nvim_feedkeys(vim.v.count1 .. "#", "n", false)
>   end
> end)
>
> vim.keymap.set("n", "*", function()
>   if not require("lsp-document-highlight").jump(vim.v.count1) then
>     vim.api.nvim_feedkeys(vim.v.count1 .. "*", "n", false)
>   end
> end)
> ```

`.enable()` and `.disable()` do what the function names suggest.\
you can also do this per-buffer by passing a filtering predicate to the `enable.buffer` key in the config.
i recommend storing a flag in `vim.b[]` and have the predicate check the flag :).

------------------------------------------------------------------------------------------------------------------------

P.S. star pls :)
