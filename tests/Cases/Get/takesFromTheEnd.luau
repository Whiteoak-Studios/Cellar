--[[
    get and remove take from the end of the idle list, as getAll shows it,
    so taking one of 400 copies leaves every other copy where it was
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 400

--[[
    Checks that an idle list lost only its last copy, and that every other
    copy kept its place
--]]

local function lostOnlyTheLast(before: { any }, after: { any }, taken: any, call: string): (boolean, string | nil)
	if taken ~= before[#before] then
		return false, `{call} took copy {table.find(before, taken)} of {#before}, not the last`
	end

	if #after ~= #before - 1 then
		return false, `{call} left {#after} idle copies of {#before}`
	end

	for index: number, copy: any in after do
		if copy ~= before[index] then
			return false, `{call} shifted the copy at {index}`
		end
	end

	return true, nil
end

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local full: { any } = cellar:getAll(pool.category).idle
	local copies: { any }? = cellar:get(nil, pool.category)
	local taken: any = copies and copies[1]
	local afterGet: { any } = cellar:getAll(pool.category).idle

	local tookLast: boolean, getReason: string? = lostOnlyTheLast(full, afterGet, taken, "get")
	if not tookLast then
		return false, getReason
	end

	-- The copy remove destroys is the one that leaves the idle list
	cellar:remove(pool.category)
	local afterRemove: { any } = cellar:getAll(pool.category).idle
	local removed: any = afterGet[#afterGet]

	local removedLast: boolean, removeReason: string? = lostOnlyTheLast(afterGet, afterRemove, removed, "remove")
	if not removedLast then
		return false, removeReason
	end

	if removed.Parent ~= nil then
		return false, `remove left the last idle copy in {removed.Parent}, so it took another`
	end

	return true, nil
end
