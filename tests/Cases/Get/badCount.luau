--[[
    get refuses a count that is not a whole number of 1 or more: zero, a
    negative count and a fraction each error at the call, naming the value,
    with idle copies there to take
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")
local RefusesBadCounts = require("../../RefusesBadCounts")

local COPY_COUNT: number = 3

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local refused: boolean, reason: string? = RefusesBadCounts("get", function (count: number)
		cellar:get(count, pool.category)
	end)
	if not refused then
		return false, reason
	end

	return true, nil
end
