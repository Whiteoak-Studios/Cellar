--[[
    An error in add surfaces at the call, both one raised before cloning and
    one raised while cloning, and the package requires no Promise
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local PROMISE: string = "ReplicatedStorage.Packages.Promise" -- Where a game installs Promise, beside the package

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)

	local nilTemplate: boolean = pcall(function ()
		cellar:add(nil, nil, pool.folder, pool.category)
	end)
	if nilTemplate then
		return false, `add with a nil template returned instead of erroring`
	end

	-- Clone gives nil for an unarchivable template, so cloning it fails
	pool.template.Archivable = false

	local failedClone: boolean = pcall(function ()
		cellar:add(pool.template, nil, pool.folder, pool.category)
	end)
	if failedClone then
		return false, `add whose clone fails returned instead of erroring`
	end

	if table.find(environment.requires, PROMISE) then
		return false, `the package required {PROMISE}`
	end

	return true, nil
end
