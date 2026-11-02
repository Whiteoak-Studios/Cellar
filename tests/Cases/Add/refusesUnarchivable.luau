--[[
    add on a template whose Archivable is false, which Clone gives nil for,
    errors at the call with a message naming the template
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)

	pool.template.Archivable = false
	cellar:create(pool.category, pool.folder)

	local ok: boolean, message: any = pcall(function ()
		cellar:add(pool.template, nil, pool.folder, pool.category)
	end)
	if ok then
		return false, `add of an unarchivable template returned instead of erroring`
	end

	if not tostring(message):find(pool.template.Name, 1, true) then
		return false, `the error does not name the template {pool.template.Name}: {message}`
	end

	return true, nil
end
