--[[
    remove destroys each idle copy it takes and leaves a copy that is out
    alone, and with no idle copy left it warns and returns false
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 3
local REMOVED: number = 2

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	-- A destroyed instance has no parent, and its Parent is locked
	local function destroyed(copy: any): boolean
		return copy.Parent == nil and not pcall(function ()
			copy.Parent = pool.folder
		end)
	end

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local made: { any } = pool.folder:GetChildren()
	local copies: { any }? = cellar:get(nil, pool.category)
	local out: any = copies and copies[1]
	if not out then
		return false, `get gave no copy to hold out`
	end

	if cellar:remove(pool.category, REMOVED) ~= true then
		return false, `remove({REMOVED}) did not return true`
	end

	for _, copy: any in made do
		if copy ~= out and not destroyed(copy) then
			return false, `remove left {copy} in the world, in {copy.Parent}`
		end
	end

	if out.Parent ~= pool.folder then
		return false, `remove touched {out}, which was out`
	end

	-- The copy that was out comes back, and remove with no count destroys it
	cellar:rebound(out)

	if cellar:remove(pool.category) ~= true or not destroyed(out) then
		return false, `remove with no count did not destroy the one idle copy`
	end

	local warned: number = #environment.warnings
	if cellar:remove(pool.category) ~= false or #environment.warnings ~= warned + 1 then
		return false, `remove with no idle copy did not warn and return false`
	end

	return true, nil
end
