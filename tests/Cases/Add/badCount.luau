--[[
    add refuses a count that is not a whole number of 1 or more: zero, a
    negative count and a fraction each error at the call, naming the value
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")
local RefusesBadCounts = require("../../RefusesBadCounts")

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)

	local refused: boolean, reason: string? = RefusesBadCounts("add", function (count: number)
		cellar:add(pool.template, count, pool.folder, pool.category)
	end)
	if not refused then
		return false, reason
	end

	return true, nil
end
