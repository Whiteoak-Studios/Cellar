--[[
    A named get takes its copy off the idle list and marks it out, so it is
    handed out once, and the other names stay idle
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local RIFLE: string = "Rifle"
local PISTOL: string = "Pistol"
local COPY_COUNT: number = 2 -- One rifle and one pistol

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)
	local rifleTemplate: any = environment.new("Part", RIFLE, environment.workspace)
	local pistolTemplate: any = environment.new("Part", PISTOL, environment.workspace)

	cellar:create(pool.category, pool.folder)
	cellar:add(rifleTemplate, nil, pool.folder, pool.category)
	cellar:add(pistolTemplate, nil, pool.folder, pool.category)

	local first: { any }? = cellar:get(nil, pool.category, RIFLE)
	local rifle: any = first and first[1]
	if not rifle or rifle.Name ~= RIFLE then
		return false, `a named get for {RIFLE} returned {rifle}`
	end

	local again: { any }? = cellar:get(nil, pool.category, RIFLE)
	if again ~= nil then
		return false, `a second named get for the one {RIFLE} handed out {again[1]}`
	end

	local rest: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not rest or #rest ~= 1 or rest[1].Name ~= PISTOL then
		return false, `after the {RIFLE} was taken, the idle copies were not the one {PISTOL}`
	end

	if cellar:rebound(rifle) ~= true then
		return false, `the {RIFLE} a named get took was not marked out, so rebound refused it`
	end

	return true, nil
end
