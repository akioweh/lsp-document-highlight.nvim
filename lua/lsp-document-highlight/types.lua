--- @meta

--- @class LDH.configFullNavigation
--- @field notify_end boolean whether to notify when reaching the top/bottom of references
--- @field open_folds boolean whether to open folds when jumping to a reference
--- @field set_jump boolean whether to set a jumplist entry when jumping to a reference

--- @class LDH.configFullEnable
--- @field modes string[] list of modes in which to enable LDH
--- @field buffers fun(buf:number):boolean a per-buffer enable predicate

--- @class LDH.configFull
--- @field throttle number minimum cooldown (in ms) between LSP requests
--- @field navigation LDH.configFullNavigation
--- @field enable LDH.configFullEnable

--- the non-full / "partial" type varaint is intended for use in
--- annotating the user's plugin config (for intellisense), where all fields are optional

--- @class LDH.configNavigation
--- @field notify_end? boolean whether to notify when reaching the top/bottom of references
--- @field open_folds? boolean whether to open folds when jumping to a reference
--- @field set_jump? boolean whether to set a jumplist entry when jumping to a reference

--- @class LDH.configEnable
--- @field modes? string[] list of modes in which to enable LDH
--- @field buffers? fun(buf:number):boolean a per-buffer enable predicate

--- @class LDH.config
--- @field throttle? number minimum cooldown (in ms) between LSP requests
--- @field navigation? LDH.configNavigation
--- @field enable? LDH.configEnable

--- @alias LDH.symbol {from:{[1]:number, [2]:number}, to:{[1]:number, [2]:number}}
