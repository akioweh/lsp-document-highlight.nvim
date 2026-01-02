local config = require("lsp-document-highlight.config")
local utils = require("lsp-document-highlight.utils")

local M = {}

local em_ns = vim.api.nvim_create_namespace("nvim.lsp.references")
local timer = vim.uv.new_timer() or error("Failed to create uv timer")
local cancel_pending = nil ---@type function?
local last_call_t = 0

M.config = config
M.setup = config.set

function M.enable()
	if M.enabled then
		return
	end
	M.enabled = true
	local group = vim.api.nvim_create_augroup("LDH", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged", "BufEnter" }, {
		group = group,
		callback = function()
			M.update() -- the wrapper is necessary to discard the event arguments
		end,
	})
end

M.init = M.enable

function M.disable()
	if not M.enabled then
		return
	end
	M.enabled = false
	vim.api.nvim_del_augroup_by_name("LDH")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		M.clear(buf)
	end
end

--- clears all highlights in the given (default current) buffer
--- @param bufnr? number
function M.clear(bufnr)
	vim.lsp.util.buf_clear_references(bufnr)
	vim.b[bufnr or 0].ldh_refs = nil
end

--- requests and renders document highlights from (all) lsp servers
--- for the current cursor position in the given (default current) buffer.
--- all this does really,
--- is to execute the behavior of `vim.lsp.buf.document_highlight()`
--- and do some post-processing after the lsp response
--- @param bufnr? number
function M.highlight(bufnr)
	bufnr = bufnr or 0
	if utils.get_cursor(bufnr)[1] == 0 then
		return -- no cursor in this buffer
	end
	if cancel_pending then
		cancel_pending()
		cancel_pending = nil
	end
	local params = function(client)
		return utils.make_position_params(bufnr, client.offset_encoding)
	end
	local method = "textDocument/documentHighlight"
	local remaining = nil
	_, cancel_pending = vim.lsp.buf_request(bufnr, method, params, function(err, result, ctx)
		if not remaining then
			remaining = #vim.lsp.get_clients({ bufnr = bufnr, method = method })
			M.clear(bufnr)
		end
		remaining = remaining - 1
		-- fall through to existing handler
		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if client then
			local handler = client.handlers[method] or vim.lsp.handlers[method]
			if handler then
				handler(err, result, ctx)
			end
		end
		-- the last lsp has responded
		if remaining == 0 then
			cancel_pending = nil
			last_call_t = vim.loop.now()
			M._compute_words(bufnr)
		end
	end, function() end)
end

--- @package
--- highlights the given (default current) buffer if enabled.
--- throttled lsp requests and cached responses for performance
--- @param bufnr? number
function M.update(bufnr)
	vim.schedule(function()
		if not M.should_highlight(bufnr) then
			M.clear(bufnr)
			return
		end
		-- update only when we've moved out of the previous word
		-- ... or if document highlights are being re-requested
		if not M.cur_ref_idx(bufnr) or cancel_pending then
			if timer:is_active() then
				return
			end
			local now = vim.loop.now()
			if now > last_call_t + config.get().throttle then
				M.highlight(bufnr)
			else -- run after throttle cooldown
				timer:start(
					math.max(0, config.get().throttle - (now - last_call_t)),
					0,
					vim.schedule_wrap(function()
						M.highlight(bufnr)
					end)
				)
			end
		end
	end)
end

--- should we highlight the given (default current) buffer?
--- @param bufnr? number buffer (default current)
--- @return boolean
function M.should_highlight(bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf() -- in case config.enable.buffers does not expect 0
	end
	local mode = vim.api.nvim_get_mode().mode:lower()
	mode = mode:gsub("\22", "v"):gsub("\19", "s") -- block modes
	mode = mode:sub(1, 2) == "no" and "o" or mode
	mode = mode:sub(1, 1):match("[ncitsvo]") or "n"
	if not vim.tbl_contains(config.get().enable.modes, mode) then
		return false
	end
	return config.get().enable.buffers(bufnr)
end

--- @package
--- @param bufnr? number
function M._compute_words(bufnr)
	bufnr = bufnr or 0
	local refs = {} --- @type LDH.symbol[]
	---@type vim.api.keyset.get_extmark_item[]
	local extmarks = vim.api.nvim_buf_get_extmarks(0, em_ns, 0, -1, { details = true })
	for _, extmark in ipairs(extmarks) do
		local w = {
			from = { extmark[2] + 1, extmark[3] },
			to = { extmark[4].end_row + 1, extmark[4].end_col },
		}
		refs[#refs + 1] = w
	end
	vim.b[bufnr].ldh_refs = refs
end

--- index of the current reference under the cursor (in the list of all references),
--- or nil if cursor has moved out of the previous set of references
--- @package
--- @param bufnr? number
--- @return number? word_idx
function M.cur_ref_idx(bufnr)
	bufnr = bufnr or 0
	local row, col = unpack(utils.get_cursor(bufnr))
	if row == 0 then
		return nil -- no cursor position
	end
	for i, w in ipairs(vim.b[bufnr].ldh_refs or {}) do
		if row >= w.from[1] and row <= w.to[1] and col >= w.from[2] and col <= w.to[2] then
			return i
		end
	end
	return nil
end

--- jumpts to the next count-th (or previous if negative) reference
--- @param count number
--- @param wrap? boolean
function M.jump(count, wrap)
	if not M.should_highlight() then
		return
	end
	local refs = vim.b[0].ldh_refs
	if not refs or #refs == 0 then
		return
	end
	local idx = M.cur_ref_idx()
	if not idx then
		return
	end
	if count == 0 then
		return
	end
	idx = idx + count
	if math.abs(count) > 1 then
		-- when jumping with a count, clamp to first/last (never wrap)
		idx = math.max(1, math.min(#refs, idx))
	elseif wrap then
		idx = (idx - 1) % #refs + 1
	end
	local target = refs[idx]
	if target then
		if config.get().navigation.set_jump then
			vim.cmd.normal({ "m`", bang = true })
		end
		vim.api.nvim_win_set_cursor(0, target.from)
		if config.get().navigation.open_folds then
			vim.cmd.normal({ "zv", bang = true })
		end
	elseif config.get().navigation.notify_end then
		vim.notify("No more references", vim.log.levels.INFO)
	end
end

return M
