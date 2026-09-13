--- @meta

--- @class LDH.configFullEnable
--- @field modes string[] list of modes in which to enable LDH
--- @field buffers fun(buf:number):boolean a per-buffer enable predicate

--- @class LDH.configFull
--- @field throttle number minimum cooldown (in ms) between LSP requests
--- @field clamp_jumps boolean when `wrapscan` off, clamp to the first/last reference instead of reporting E384/E385
--- @field enable LDH.configFullEnable

--- the non-full / "partial" type varaint is intended for use in
--- annotating the user's plugin config (for intellisense), where all fields are optional

--- @class LDH.configEnable
--- @field modes? string[] list of modes in which to enable LDH
--- @field buffers? fun(buf:number):boolean a per-buffer enable predicate

--- @class LDH.config
--- @field throttle? number minimum cooldown (in ms) between LSP requests
--- @field clamp_jumps boolean when `wrapscan` off, clamp to the first/last reference instead of reporting E384/E385
--- @field enable? LDH.configEnable

--- @alias LDH.symbol {l: [number, number], r: [number, number]} [(row, col), (row, col)]

--- @class LDH.JumpResult
--- @field cur integer 1-based index of the jumped-to reference
--- @field cnt integer number of references
--- @field wrapped boolean whether the jump crossed the reference set boundary
