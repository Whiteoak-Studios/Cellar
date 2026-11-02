--[[
    An idle copy whose Parent is nil, as a copy destroyed under deferred
    signals is before its Destroying runs, is never handed out: get takes
    the next idle copy instead, and getAll no longer lists it
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 3
local GONE: number = 2 -- The copy unparented and the copy get took

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	-- Unparent the copy get would take next, so the one behind it is the copy get must take
	local idle: { any } = cellar:getAll(pool.category).idle
	local unparented: any = idle[#idle]
	local behind: any = idle[#idle - 1]
	unparented.Parent = nil

	local copies: { any }? = cellar:get(nil, pool.category)
	local copy: any = copies and copies[1]
	if copy == unparented then
		return false, `get handed out the idle copy whose Parent is nil`
	end

	if not copy or copy ~= behind then
		return false, `get did not take the idle copy behind the one whose Parent is nil`
	end

	local after = cellar:getAll(pool.category)
	if table.find(after.idle, unparented) or table.find(after.out, unparented) then
		return false, `getAll still lists the idle copy whose Parent is nil`
	end

	if #after.idle ~= COPY_COUNT - GONE then
		return false, `{#after.idle} copies are idle, not the {COPY_COUNT - GONE} left untouched`
	end

	return true, nil
end
