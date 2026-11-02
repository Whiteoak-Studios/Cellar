--[[
    Times one getAll on a pool with half its copies out, so the call copies
    the idle list and walks and sorts the out record, to show whether it
    belongs at boot or on a settings change rather than on a hot path
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Cellar = require(Packages.Cellar)

local Measure = require(ServerScriptService.Dev.Measure)
local Templates = require(ServerScriptService.Dev.Templates)

local OUT_SHARE: number = 0.5 -- The share of the pool taken out before getAll is timed

type Pool = Measure.Pool

return function (): string
	local template: Part = Templates.part("Copy")

	local report: string = Measure("getAll", function (pool: Pool)
		Cellar:create(pool.category, pool.folder)
		Cellar:add(template, pool.size, nil, pool.category)
		Cellar:get(math.floor(pool.size * OUT_SHARE), pool.category)
	end, function (pool: Pool): number
		local started: number = os.clock()
		Cellar:getAll(pool.category)

		return os.clock() - started
	end)

	template:Destroy()

	return report
end
