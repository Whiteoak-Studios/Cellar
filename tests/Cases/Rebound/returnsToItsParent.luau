--[[
    A copy given back with rebound lands in its category's parent, wherever
    it was while out, and sits at the park point
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")
local Pool = require("../../Pool")

local IN_USE_FOLDER: string = "InUse"
local IN_USE_CFRAME: CFrame = roblox.CFrame.new(10, 20, 30) -- Where the copy is used while it is out

return function (): (boolean, string | nil)
	local environment: Environment.Loaded = Environment.load()
	local cellar: any = environment.cellar
	local pool: Pool.Pool = Pool(environment)
	local inUse: any = environment.new("Folder", IN_USE_FOLDER, environment.workspace)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, nil, pool.folder, pool.category)

	local copies: { any }? = cellar:get(nil, pool.category)
	local copy: any = copies and copies[1]
	if not copy then
		return false, `get gave no copy to use`
	end

	copy.Parent = inUse
	copy.CFrame = IN_USE_CFRAME

	if cellar:rebound(copy) ~= true then
		return false, `rebound of a copy that was out did not return true`
	end

	if copy.Parent ~= pool.folder then
		return false, `the rebounded copy sits in {copy.Parent}, not its category's parent`
	end

	if copy.CFrame ~= pool.park then
		return false, `the rebounded copy sits at {copy.CFrame}, not the park point {pool.park}`
	end

	return true, nil
end
