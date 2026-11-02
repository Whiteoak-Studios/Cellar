--[[
    A second create of a category name warns, returns false and keeps the
    first category: the copies it holds and the parent it was given
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local OTHER_FOLDER: string = "Elsewhere"
local COPY_COUNT: number = 2 -- One add before the second create and one after

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)
	local elsewhere: any = environment.new("Folder", OTHER_FOLDER, environment.workspace)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, nil, pool.folder, pool.category)

	local again: any = cellar:create(pool.category, elsewhere)
	if again ~= false then
		return false, `a second create returned {again}, not false`
	end

	if #environment.warnings ~= 1 then
		return false, `a second create warned {#environment.warnings} times, not once`
	end

	-- An add with no parent still lands in the first category's folder
	cellar:add(pool.template, nil, nil, pool.category)

	local copies: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not copies or #copies ~= COPY_COUNT then
		return false, `the category held {copies and #copies or 0} copies after the second create, not {COPY_COUNT}`
	end

	for _, copy: any in copies do
		if copy.Parent ~= pool.folder then
			return false, `a copy sits in {copy.Parent}, not the first create's folder`
		end
	end

	return true, nil
end
