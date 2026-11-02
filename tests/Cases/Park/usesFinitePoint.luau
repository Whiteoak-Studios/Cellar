--[[
    A parked Model and a parked BasePart sit at the one finite park point,
    never at an infinite CFrame, both when add makes them and when rebound
    gives them back
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")
local Pool = require("../../Pool")

local MODEL_NAME: string = "Crate"
local LID_NAME: string = "Lid"
local BASE_NAME: string = "Base"
local LID_CFRAME: CFrame = roblox.CFrame.new(0, 2, 0)
local COPY_COUNT: number = 2 -- One Model and one part

--[[
    Checks that every copy in a folder sits at the park point, a Model by
    its pivot and a part by its CFrame
--]]

local function parked(folder: any, park: CFrame, moment: string): (boolean, string | nil)
	for _, copy: any in folder:GetChildren() do
		local at: CFrame = copy:IsA("Model") and copy:GetPivot() or copy.CFrame
		if at ~= park then
			return false, `{moment}, {copy} sits at {at}, not the park point {park}`
		end
	end

	return true, nil
end

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)

	local model = environment.new("Model", MODEL_NAME, environment.workspace)
	local lid = environment.new("Part", LID_NAME, model)
	lid.CFrame = LID_CFRAME
	environment.new("Part", BASE_NAME, model)

	cellar:create(pool.category, pool.folder)
	cellar:add(pool.template, nil, pool.folder, pool.category)
	cellar:add(model, nil, pool.folder, pool.category)

	local afterAdd: boolean, addReason: string? = parked(pool.folder, pool.park, "after add")
	if not afterAdd then
		return false, addReason
	end

	local copies: { any }? = cellar:get(COPY_COUNT, pool.category)
	if not copies or #copies ~= COPY_COUNT then
		return false, `get({COPY_COUNT}) did not return both copies`
	end

	for _, copy: any in copies do
		cellar:rebound(copy)
	end

	local afterRebound: boolean, reboundReason: string? = parked(pool.folder, pool.park, "after rebound")
	if not afterRebound then
		return false, reboundReason
	end

	return true, nil
end
