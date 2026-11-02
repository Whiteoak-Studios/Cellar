--[[
    get with a count larger than the pool returns every idle copy, and the
    pool is empty after it
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local COPY_COUNT: number = 2
local ASKED: number = 5

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, COPY_COUNT, pool.folder, pool.category)

	local made: { any } = pool.folder:GetChildren()

	local copies: { any }? = cellar:get(ASKED, pool.category)
	if not copies or #copies ~= COPY_COUNT then
		return false, `get({ASKED}) from {COPY_COUNT} copies returned {copies and #copies or 0} values`
	end

	for index: number, copy: any in copies do
		if not table.find(made, copy) then
			return false, `get({ASKED}) returned {copy}, which is not one of the pool's copies`
		end

		if table.find(copies, copy) ~= index then
			return false, `get({ASKED}) returned {copy} twice`
		end
	end

	-- An empty category returns nil, with a count or without
	if cellar:get(ASKED, pool.category) ~= nil or cellar:get(nil, pool.category) ~= nil then
		return false, `get on an emptied category returned something`
	end

	return true, nil
end
