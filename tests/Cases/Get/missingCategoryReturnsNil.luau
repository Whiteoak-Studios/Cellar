--[[
    get on a category nobody created returns nil at once, with no yield,
    with or without a count and a name
--]]

--!strict
local task = require("@lune/task")

local Environment = require("../../Environment")

local MISSING: string = "Missing"
local COUNT: number = 2
local NAME: string = "Marker"

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar

	local finished: boolean = false
	local single: any = false
	local counted: any = false

	-- A yield leaves the spawned thread unfinished when task.spawn returns
	task.spawn(function ()
		single = cellar:get(nil, MISSING)
		counted = cellar:get(COUNT, MISSING, NAME)
		finished = true
	end)

	if not finished then
		return false, `get on the unknown category {MISSING} yielded`
	end

	if single ~= nil or counted ~= nil then
		return false, `get on the unknown category {MISSING} returned something, not nil`
	end

	return true, nil
end
