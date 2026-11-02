--[[
    get takes its arguments as count, category and name, and the name may
    be left out, with a count or without one
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local RIFLE: string = "Rifle"
local PISTOL: string = "Pistol"
local PISTOL_COUNT: number = 2
local TAKE_ONE: number = 1

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)
	local rifleTemplate = environment.new("Part", RIFLE, environment.workspace)
	local pistolTemplate = environment.new("Part", PISTOL, environment.workspace)

	cellar:create(pool.category, pool.folder)
	cellar:add(pistolTemplate, PISTOL_COUNT, pool.folder, pool.category)
	cellar:add(rifleTemplate, nil, pool.folder, pool.category)

	local made: { any } = pool.folder:GetChildren()
	local taken: { any } = {}

	local named: { any }? = cellar:get(TAKE_ONE, pool.category, PISTOL)
	if not named or #named ~= TAKE_ONE or named[1].Name ~= PISTOL then
		return false, `get({TAKE_ONE}, {pool.category}, {PISTOL}) did not return one {PISTOL}`
	end

	table.insert(taken, named[1])

	-- The name left out, with a count and then without one
	local counted: { any }? = cellar:get(TAKE_ONE, pool.category)
	local single: { any }? = cellar:get(nil, pool.category)

	-- A missing result becomes an empty list, since a nil would leave a hole the loop skips
	for _, copies: { any } in { counted or {}, single or {} } do
		if #copies ~= TAKE_ONE then
			return false, `get with no name did not return one copy`
		end

		if not table.find(made, copies[1]) or table.find(taken, copies[1]) then
			return false, `get with no name returned {copies[1]}, which is not an idle copy of the pool`
		end

		table.insert(taken, copies[1])
	end

	return true, nil
end
