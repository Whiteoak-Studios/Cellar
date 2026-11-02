--[[
    Times add of one tree shaped like Echo's voice into a pool already that
    size, the cost Echo's pool growth pays mid-game; the new copy is removed
    again, untimed, so the pool keeps its size
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Cellar = require(Packages.Cellar)

local Measure = require(ServerScriptService.Dev.Measure)
local Templates = require(ServerScriptService.Dev.Templates)

type Pool = Measure.Pool

return function (): string
	local voice: Folder = Templates.voice()

	local report: string = Measure("addAtRuntime", function (pool: Pool)
		Cellar:create(pool.category, pool.folder)
		Cellar:add(voice, pool.size, nil, pool.category)
	end, function (pool: Pool): number
		local started: number = os.clock()
		Cellar:add(voice, nil, nil, pool.category)
		local elapsed: number = os.clock() - started

		-- Untimed: destroy the new copy, the last on the idle list
		Cellar:remove(pool.category)

		return elapsed
	end)

	voice:Destroy()

	return report
end
