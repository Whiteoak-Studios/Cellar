--[[
    getAll lists a category's idle and out copies in fresh arrays, so
    changing them changes nothing in the pool, and gives nil for a category
    nobody created
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 3
local MISSING: string = "Missing"

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local copies: { any }? = cellar:get(nil, pool.category)
	local out: any = copies and copies[1]

	local first = cellar:getAll(pool.category)
	if not first then
		return false, `getAll gave nil for a category that exists`
	end

	if #first.out ~= 1 or first.out[1] ~= out then
		return false, `getAll's out list is not the one copy taken`
	end

	if #first.idle ~= COPY_COUNT - 1 or table.find(first.idle, out) then
		return false, `getAll's idle list is not the {COPY_COUNT - 1} copies left`
	end

	-- Changing the returned arrays changes nothing in the pool
	table.clear(first.idle)
	table.insert(first.out, pool.template)

	local second = cellar:getAll(pool.category)
	if #second.idle ~= COPY_COUNT - 1 or #second.out ~= 1 then
		return false, `changing getAll's arrays changed the next getAll`
	end

	local idle: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not idle or #idle ~= COPY_COUNT - 1 then
		return false, `changing getAll's arrays changed what get takes`
	end

	if cellar:getAll(MISSING) ~= nil then
		return false, `getAll on the unknown category {MISSING} did not return nil`
	end

	return true, nil
end
