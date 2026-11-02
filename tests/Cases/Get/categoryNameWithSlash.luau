--[[
    A category name with slashes, such as FX/Casing/Rifle, works in every
    call, and is one name, not a path: its prefix is a separate category
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local CATEGORY: string = "FX/Casing/Rifle"
local PREFIX: string = "FX/Casing"
local COPY_COUNT: number = 2

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	if cellar:create(CATEGORY, pool.folder) ~= true then
		return false, `create of {CATEGORY} did not return true`
	end

	if cellar:add(pool.template, COPY_COUNT, pool.folder, CATEGORY) ~= true then
		return false, `add to {CATEGORY} did not return true`
	end

	local copies: { any }? = cellar:get(nil, CATEGORY)
	local copy: any = copies and copies[1]
	if not copy or cellar:rebound(copy) ~= true then
		return false, `a copy of {CATEGORY} could not be taken and given back`
	end

	if cellar:remove(CATEGORY) ~= true then
		return false, `remove from {CATEGORY} did not return true`
	end

	-- The prefix is no category until it is created, and then a category of its own
	if cellar:getAll(PREFIX) ~= nil or cellar:get(nil, PREFIX) ~= nil then
		return false, `{PREFIX} answered as a category before anyone created it`
	end

	if cellar:create(PREFIX, pool.folder) ~= true then
		return false, `create of {PREFIX} failed beside {CATEGORY}`
	end

	return true, nil
end
