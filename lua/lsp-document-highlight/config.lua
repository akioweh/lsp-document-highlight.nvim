local M = {}

--- @type LDH.configFull
M.DEFAULT = {
	throttle = 150,
	navigation = {
		notify_end = true,
		open_folds = true,
		set_jump = true,
	},
	enable = {
		modes = { "n", "c" }, -- c is included so highlights don't disappear when typing commands
		---@diagnostic disable-next-line: unused-local
		buffers = function(buf)
			return true
		end,
	},
}

--- @type LDH.configFull
M._cur = vim.deepcopy(M.DEFAULT)

--- @return LDH.configFull
function M.get()
	return M._cur
end

--- @param opts LDH.config
function M.validate(opts)
	--- @param o table
	--- @param schema table
	--- @param path string[]
	local function go(o, schema, path)
		for k, v in pairs(o) do
			local cur_path = table.concat(path, ".") .. "." .. k
			if schema[k] == nil then
				error("Unexpected field at " .. cur_path)
			end
			if type(v) ~= type(schema[k]) then
				error(
					"Invalid type for field "
						.. cur_path
						.. " (expected "
						.. type(schema[k])
						.. ", got "
						.. type(v)
						.. ")"
				)
			elseif type(v) == "table" then
				path[#path + 1] = k
				go(v, schema[k], path)
				path[#path] = nil
			end
		end
	end
	go(opts, M.DEFAULT, {})
end

--- @param opts LDH.config
function M.update(opts)
	local ok, err = pcall(M.validate, opts)
	if not ok then
		error("Config validation error: " .. err)
	end
	M._cur = vim.tbl_deep_extend("force", M.get(), opts)
end

--- @param opts LDH.config
function M.set(opts)
	local ok, err = pcall(M.validate, opts)
	if not ok then
		error("Config validation error: " .. err)
	end
	M._cur = vim.tbl_deep_extend("force", M.DEFAULT, opts)
end

return M
