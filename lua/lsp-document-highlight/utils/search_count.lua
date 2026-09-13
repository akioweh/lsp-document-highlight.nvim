--- API replicating core's built-in search count message printing:
---  - `format()` for the "[n/m]" search count string,
---  - `compose()` for the full message line (pattern + padding + `format()`),
---  - `emit()` for `compose()` plus side effects and `nvim_echo`
---
--- Replicated built-in behavior:
---  - Suffix formatting, including the "W", "?", ">" and 'rightleft' forms.
---  - Message buffer width for a fresh message: `v:echospace` in the TUI at any cmdheight, `pattern + 17` with an `ext_messages` UI (for UIs listed by `nvim_list_uis()`).
---  - Emission: `kind = "search_count"`, `history = false`, `v:warningmsg` / `v:statusmsg`.
---
--- Behavioral differences:
---  - Conditional emission: `messaging()`, `msg_silent` and 'shortmess' "S" checks are the caller's responsibility; `cmd_silent` does not stop emission (it only omits the echoed pattern).
---  - in-place message replacement (internal `replace_last` flag, inaccessible here); a stable `id` (`"search_count"`) is used as its substitute.
---  - Placement while messages are scrolled or mid-write (`msg_row` / `msg_scrolled` are unobservable).
---  - Pattern truncation of oversized buffers: truncated as a pattern, not as core's padded buffer.

local M = {}

---@class SearchCountMsgOpts
---@field cur integer          current match, 1-indexed
---@field cnt integer          total matches
---@field maxcount? integer    (for formatting) defaults to 'maxsearchcount' (<= 0 means unlimited)
---@field incomplete? 0|1|2    0 complete; 1 timed out; 2 max count exceeded
---@field wrapped? boolean     (for formatting) search wrapped?
---@field rightleft? boolean   defaults to 'rightleft' with "s" in 'rightleftcmd'.
---@field pattern? string      search pattern to also print
---@field width? integer       Total message cell width. Defaults to core's msgbuf width (see default_width()).

---@return boolean
local function is_rightleft()
  return vim.wo.rightleft and vim.wo.rightleftcmd:find("s", 1, true) ~= nil
end

--- whether a UI with `ext_messages` is attached
--- (per `nvim_list_uis()`; UIs attached with `vim.ui_attach()` are not listed)
---@return boolean
local function has_ext_messages()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.ext_messages then
      return true
    end
  end
  return false
end

--- nvim core's message-area width for a fresh message at the first cmdline row
---@param pattern string
---@return integer
local function default_width(pattern)
  if has_ext_messages() then
    -- ext buffer: plen + off_len + SEARCH_STAT_BUF_LEN + 3, minus the NUL
    return vim.api.nvim_strwidth(pattern) + 17
  end
  -- builtin TUI buffer: (Rows - msg_row - 1) * Columns + sc_col - 1, minus the NUL
  return math.max((vim.o.cmdheight - 1) * vim.o.columns + math.max(vim.v.echospace - 1, 0), 1)
end

--- middle-truncate a string to `room` cells (like nvim core `trunc_string()`).
---@param s string
---@param room integer
---@return string
local function trunc_cells(s, room)
  if vim.api.nvim_strwidth(s) <= room then
    return s
  end
  if room <= 3 then
    return string.rep(".", math.max(room, 0))
  end
  local budget = room - 3
  local head_budget = math.ceil(budget / 2)
  local tail_budget = budget - head_budget

  ---@param from_start boolean
  ---@param limit integer
  ---@return string
  local function take(from_start, limit)
    local n = vim.fn.strchars(s)
    local out, used = {}, 0
    local i = from_start and 1 or n
    while used < limit and i >= 1 and i <= n do
      local c = vim.fn.strcharpart(s, i - 1, 1)
      local w = vim.api.nvim_strwidth(c)
      if used + w > limit then
        break
      end
      used = used + w
      out[#out + 1] = c
      i = i + (from_start and 1 or -1)
    end
    if not from_start then
      local rev = {}
      for j = #out, 1, -1 do
        rev[#rev + 1] = out[j]
      end
      out = rev
    end
    return table.concat(out)
  end

  return take(true, head_budget) .. "..." .. take(false, tail_budget)
end

--- format the "[n/m]" suffix (like nvim core `cmdline_search_stat()`)
---@param o SearchCountMsgOpts
---@return string? `nil` when core would not emit a message (`cur <= 0`).
function M.format(o)
  if o.cur <= 0 then
    return nil
  end

  local rl = o.rightleft
  if rl == nil then
    rl = is_rightleft()
  end

  local t
  if o.incomplete == 1 then
    t = "[?/??]"
  else
    local max = o.maxcount or vim.o.maxsearchcount
    local capped = max > 0 and o.cnt > max
    if capped and o.cur > max then
      t = ("[>%d/>%d]"):format(max, max)
    elseif capped then
      t = rl and ("[>%d/%d]"):format(max, o.cur) or ("[%d/>%d]"):format(o.cur, max)
    else
      t = rl and ("[%d/%d]"):format(o.cnt, o.cur) or ("[%d/%d]"):format(o.cur, o.cnt)
    end
  end

  if o.wrapped and not vim.o.shortmess:find("s", 1, true) then
    t = "W " .. t
  end
  return t
end

---@param s string
---@return string
local function reverse_chars(s)
  local n = vim.fn.strchars(s)
  if n <= 1 then
    return s
  end
  local out = {}
  for i = n, 1, -1 do
    out[#out + 1] = vim.fn.strcharpart(s, i - 1, 1)
  end
  return table.concat(out)
end

--- compose the full message line: search pattern on the left, count right-aligned at `width`.
---
--- NOTE: nvim core (`msg_strtrunc()`) middle-truncates its whole space-padded buffer;
--- this middle-truncates only the pattern
---
---@param o SearchCountMsgOpts
---@return string?
function M.compose(o)
  local opts = vim.tbl_extend("force", {}, o)
  if opts.rightleft == nil then
    opts.rightleft = is_rightleft()
  end

  local t = M.format(opts)
  if not t then
    return nil
  end

  local pattern = opts.pattern or ""
  if opts.rightleft and pattern ~= "" then
    pattern = reverse_chars(pattern)
  end

  local width = opts.width or default_width(pattern)
  local tw = vim.api.nvim_strwidth(t)
  if vim.api.nvim_strwidth(pattern) + tw > width then
    pattern = trunc_cells(pattern, width - tw)
  end

  local pad = width - vim.api.nvim_strwidth(pattern) - tw
  return pattern .. string.rep(" ", math.max(pad, 0)) .. t
end

--- emit a search-count message: `msg_show` with
--- `kind = "search_count"`, `history = false`, and `id = "search_count"`.
--- also sets `v:warningmsg` and `v:statusmsg`
---@param o SearchCountMsgOpts
---@return string? The emitted message, or `nil` when nothing was emitted.
function M.emit(o)
  local msg = M.compose(o)
  if not msg then
    return nil
  end

  vim.v.warningmsg = msg
  vim.v.statusmsg = msg
  vim.api.nvim_echo({ { msg } }, false, { kind = "search_count", id = "search_count" })
  return msg
end

return M
