--[[
    rebound of a copy that is not out warns and returns false: an idle copy
    never taken, an instance never pooled, and a copy already given back
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local STRANGER: string = "Stranger"
local COPY_COUNT: number = 2

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)
	local stranger = environment.new("Part", STRANGER, environment.workspace)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local copies: { any }? = cellar:get(nil, pool.category)
	local taken: any = copies and copies[1]
	local idle: any = nil
	for _, copy: any in pool.folder:GetChildren() do
		if copy ~= taken then
			idle = copy
		end
	end

	if not taken or not idle or cellar:rebound(taken) ~= true then
		return false, `a copy taken with get could not be given back`
	end

	-- After the one rebound, the idle copy, a stranger and the same copy again are all refused
	for _, instance: any in { idle, stranger, taken } do
		local warned: number = #environment.warnings
		local result: any = cellar:rebound(instance)

		if result ~= false then
			return false, `rebound of {instance}, which was not out, returned {result}, not false`
		end

		if #environment.warnings ~= warned + 1 then
			return false, `rebound of {instance}, which was not out, did not warn`
		end
	end

	local all: { any }? = cellar:get(COPY_COUNT + 1, pool.category)
	if not all or #all ~= COPY_COUNT then
		return false, `refused rebounds changed the pool: it holds {all and #all or 0} copies, not {COPY_COUNT}`
	end

	return true, nil
end
