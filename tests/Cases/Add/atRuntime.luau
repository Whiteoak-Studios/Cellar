--[[
    A template that is not in the DataModel, such as a tree built in memory
    at runtime, still clones into the pool
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local LOOSE_TEMPLATE: string = "Loose"

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)
	local template: any = environment.new("Part", LOOSE_TEMPLATE, nil)

	cellar:create(pool.category, pool.folder)

	local ok: boolean, result: any = pcall(function ()
		return cellar:add(template, nil, pool.folder, pool.category)
	end)
	if not ok then
		return false, `add of a template outside the DataModel errored: {result}`
	end

	if result ~= true then
		return false, `add of a template outside the DataModel returned {result}, not true`
	end

	local copies: { any }? = cellar:get(nil, pool.category)
	local copy: any = copies and copies[1]
	if not copy or copy.Name ~= LOOSE_TEMPLATE or copy.Parent ~= pool.folder then
		return false, `the pool holds no copy of the template outside the DataModel`
	end

	return true, nil
end
