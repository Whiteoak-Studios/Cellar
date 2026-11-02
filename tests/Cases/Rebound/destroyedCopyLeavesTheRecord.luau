--[[
    A copy destroyed while out leaves the out record, and one destroyed
    while idle leaves the idle list, so get never hands it out
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 2

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local copies: { any }? = cellar:get(nil, pool.category)
	local out: any = copies and copies[1]
	if not out then
		return false, `get gave no copy to destroy`
	end

	out:Destroy()

	local afterOut: { idle: { any }, out: { any } } = cellar:getAll(pool.category)
	if table.find(afterOut.out, out) or #afterOut.out ~= 0 then
		return false, `a copy destroyed while out stayed in the out record`
	end

	local idle: any = afterOut.idle[1]
	if not idle or #afterOut.idle ~= COPY_COUNT - 1 then
		return false, `destroying the copy that was out changed the idle list`
	end

	idle:Destroy()

	local afterIdle: { idle: { any }, out: { any } } = cellar:getAll(pool.category)
	if #afterIdle.idle ~= 0 then
		return false, `a copy destroyed while idle stayed in the idle list`
	end

	if cellar:get(nil, pool.category) ~= nil then
		return false, `get handed out a copy destroyed while idle`
	end

	return true, nil
end
