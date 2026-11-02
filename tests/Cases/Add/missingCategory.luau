--[[
    add to a category nobody created errors at the call
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local MISSING: string = "Missing"

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	local ok: boolean = pcall(function ()
		cellar:add(pool.template, nil, pool.folder, MISSING)
	end)
	if ok then
		return false, `add to the unknown category {MISSING} returned instead of erroring`
	end

	return true, nil
end
