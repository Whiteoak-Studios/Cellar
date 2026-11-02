--[[
    Times get(nil, category) and rebound as one pair on a pool of anchored
    parts, the cost that must stay the same at every pool size
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
	local template: Part = Templates.part("Copy")

	local report: string = Measure("getOne", function (pool: Pool)
		Cellar:create(pool.category, pool.folder)
		Cellar:add(template, pool.size, nil, pool.category)
	end, function (pool: Pool): number
		local started: number = os.clock()
		local copies = Cellar:get(nil, pool.category) :: { Instance }
		Cellar:rebound(copies[1])

		return os.clock() - started
	end)

	template:Destroy()

	return report
end
