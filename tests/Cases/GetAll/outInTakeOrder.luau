--[[
    getAll lists the out copies in the order get took them, across single
    and counted gets, and a copy given back in the middle leaves its place
    and joins the end when get takes it again
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 6
local PAIR: number = 2 -- The count of each counted get

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local expected: { any } = {} -- Every copy out, in the order get took it

	-- Takes copies and records them in the order get gave them
	local function take(count: number?): any
		local copies: { any }? = cellar:get(count, pool.category)
		for _, copy: any in copies or {} do
			table.insert(expected, copy)
		end

		return copies and copies[1]
	end

	take(nil)
	local given: any = take(PAIR)
	take(nil)

	-- 1) The copy given back leaves its place in the order
	if not given or cellar:rebound(given) ~= true then
		return false, `a copy taken by a counted get could not be given back`
	end

	local index: number? = table.find(expected, given)
	if index then
		table.remove(expected, index)
	end

	-- 2) The next get takes it again, since the idle list is last in, first out, so it joins the end
	take(PAIR)

	local out: { any } = cellar:getAll(pool.category).out
	if #out ~= #expected then
		return false, `getAll listed {#out} out copies, not the {#expected} get took`
	end

	for place: number, copy: any in expected do
		if out[place] ~= copy then
			return false, `getAll's out copy {place} of {#expected} is not the one get took at that place`
		end
	end

	return true, nil
end
