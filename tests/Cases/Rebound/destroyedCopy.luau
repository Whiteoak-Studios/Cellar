--[[
    rebound on a copy destroyed while out does not throw, warns and returns
    false, and the copy never rejoins the pool
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, nil, pool.folder, pool.category)

	local copies: { any }? = cellar:get(nil, pool.category)
	local copy: any = copies and copies[1]
	if not copy then
		return false, `get gave no copy to destroy`
	end

	copy:Destroy()

	local warned: number = #environment.warnings
	local ok: boolean, result: any = pcall(function ()
		return cellar:rebound(copy)
	end)
	if not ok then
		return false, `rebound on a destroyed copy threw: {result}`
	end

	if result ~= false then
		return false, `rebound on a destroyed copy returned {result}, not false`
	end

	if #environment.warnings ~= warned + 1 then
		return false, `rebound on a destroyed copy did not warn`
	end

	local after: { any }? = cellar:get(nil, pool.category)
	if after ~= nil then
		return false, `the destroyed copy rejoined the pool and get handed out {after[1]}`
	end

	return true, nil
end
