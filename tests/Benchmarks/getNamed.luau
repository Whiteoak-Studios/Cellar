--[[
    Times a named get, get(nil, category, name), whose one copy of that
    name sits at the far end of the idle list behind every other copy, so
    the get scans the whole pool before it takes it
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Cellar = require(Packages.Cellar)

local Measure = require(ServerScriptService.Dev.Measure)
local Templates = require(ServerScriptService.Dev.Templates)

local TARGET: string = "Target" -- The one copy the named get looks for
local FILLER: string = "Filler" -- Every other copy in the pool

type Pool = Measure.Pool

return function (): string
	local target: Part = Templates.part(TARGET)
	local filler: Part = Templates.part(FILLER)

	local report: string = Measure("getNamed", function (pool: Pool)
		Cellar:create(pool.category, pool.folder)

		-- Added first, so it sits at the far end of the idle list, where get reaches it last
		Cellar:add(target, nil, nil, pool.category)
		Cellar:add(filler, pool.size - 1, nil, pool.category)
	end, function (pool: Pool): number
		local started: number = os.clock()
		local copies = Cellar:get(nil, pool.category, TARGET) :: { Instance }
		local elapsed: number = os.clock() - started

		-- Untimed: give the target back, then take every filler out and give each back behind it
		Cellar:rebound(copies[1])
		for _, copy: Instance in Cellar:get(pool.size - 1, pool.category, FILLER) :: { Instance } do
			Cellar:rebound(copy)
		end

		return elapsed
	end)

	target:Destroy()
	filler:Destroy()

	return report
end
