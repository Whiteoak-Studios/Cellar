--[[
    The pool most cases build: a category name, a folder for its copies and
    a part template, both in the workspace, and the finite point a parked
    copy must sit at
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("./Environment")

local CATEGORY: string = "Markers"
local FOLDER_NAME: string = "Pool"
local TEMPLATE_NAME: string = "Marker"
local PARK_CFRAME: CFrame = roblox.CFrame.new(0, -100000, 0)

export type Pool = {
	category: string,
	folder: any,
	template: any,
	park: CFrame,
}

return function (environment: Environment.Loaded): Pool
	return {
		category = CATEGORY,
		folder = environment.new("Folder", FOLDER_NAME, environment.workspace),
		template = environment.new("Part", TEMPLATE_NAME, environment.workspace),
		park = PARK_CFRAME,
	}
end
