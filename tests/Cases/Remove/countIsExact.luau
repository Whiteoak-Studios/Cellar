--[[
    remove with a count of 2 removes two idle copies, no more, and remove
    on a category nobody created errors at the call
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 4
local REMOVED: number = 2
local MISSING: string = "Missing"

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	if cellar:remove(pool.category, REMOVED) ~= true then
		return false, `remove({REMOVED}) did not return true`
	end

	local left: { any }? = cellar:get(COPY_COUNT, pool.category)
	local leftCount: number = left and #left or 0
	if leftCount ~= COPY_COUNT - REMOVED then
		return false, `remove({REMOVED}) from {COPY_COUNT} copies left {leftCount}, not {COPY_COUNT - REMOVED}`
	end

	local ok: boolean = pcall(function ()
		cellar:remove(MISSING)
	end)
	if ok then
		return false, `remove from the unknown category {MISSING} returned instead of erroring`
	end

	return true, nil
end
