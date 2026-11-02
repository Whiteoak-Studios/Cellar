--[[
    get with a count of 2 returns two of the pool's copies, marks both out
    so no later get hands them out, and loses no copy
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 3
local TAKEN: number = 2

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local made: { any } = pool.folder:GetChildren()

	local copies: { any }? = cellar:get(TAKEN, pool.category)
	if not copies or #copies ~= TAKEN then
		return false, `get({TAKEN}) returned {copies and #copies or 0} values, not {TAKEN}`
	end

	for index: number, copy: any in copies do
		if not table.find(made, copy) then
			return false, `get({TAKEN}) returned {copy}, which is not one of the pool's copies`
		end

		if table.find(copies, copy) ~= index then
			return false, `get({TAKEN}) returned {copy} twice`
		end
	end

	-- Marked out: the rest of the pool is the one copy not taken
	local rest: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not rest or #rest ~= COPY_COUNT - TAKEN or table.find(copies, rest[1]) then
		return false, `a later get handed out a copy already out, or missed the one still idle`
	end

	table.insert(copies, rest[1])
	for _, copy: any in copies do
		if cellar:rebound(copy) ~= true then
			return false, `{copy} was not marked out, so rebound refused it`
		end
	end

	-- Lost none: every copy made is idle again
	local all: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not all or #all ~= COPY_COUNT then
		return false, `the pool holds {all and #all or 0} copies after every one came back, not {COPY_COUNT}`
	end

	return true, nil
end
