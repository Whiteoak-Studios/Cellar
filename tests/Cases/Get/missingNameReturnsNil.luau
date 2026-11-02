--[[
    A named get with no copy of that name returns nil, with a count or
    without, and takes nothing from the pool
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 2
local MISSING_NAME: string = "Missing"

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local single: any = cellar:get(nil, pool.category, MISSING_NAME)
	if single ~= nil then
		return false, `get(nil, {pool.category}, {MISSING_NAME}) returned {single[1]}, not nil`
	end

	local counted: any = cellar:get(COPY_COUNT, pool.category, MISSING_NAME)
	if counted ~= nil then
		return false, `get({COPY_COUNT}, {pool.category}, {MISSING_NAME}) returned {#counted} values, not nil`
	end

	local all: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not all or #all ~= COPY_COUNT then
		return false, `a named get with no match took copies: {all and #all or 0} of {COPY_COUNT} left`
	end

	return true, nil
end
