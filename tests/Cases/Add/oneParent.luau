--[[
    One parent per category: a category created with none takes the first
    add's, or the workspace when that add passes none, nil means the
    category's parent, and an add naming a different one errors at the
    call, naming both
--]]

--!strict
local Environment = require("../../Environment")
local Pool = require("../../Pool")

local CLAIMED: string = "Claimed" -- Created with no parent, then settled by an add that names one
local UNSETTLED: string = "Unsettled" -- Created with no parent, then settled by an add that names none
local DECLARED: string = "Declared" -- Created with a parent
local STRAY_FOLDER: string = "Stray"
local IN_USE_FOLDER: string = "InUse"
local CLAIMED_COUNT: number = 2 -- One add naming the folder and one naming none

--[[
    Checks that an add naming a parent other than the category's errors,
    and that its message names both parents
--]]

local function refuses(cellar: any, template: any, stray: any, category: string, parent: any): (boolean, string | nil)
	local ok: boolean, message: any = pcall(function ()
		cellar:add(template, nil, stray, category)
	end)
	if ok then
		return false, `an add to {category} naming {stray}, not {parent}, returned instead of erroring`
	end

	local text: string = tostring(message)
	if not text:find(parent.Name, 1, true) or not text:find(stray.Name, 1, true) then
		return false, `the error for {category} does not name both {parent} and {stray}: {text}`
	end

	return true, nil
end

return function (): (boolean, string | nil)
	local environment = Environment.load()
	local cellar = environment.cellar
	local pool = Pool(environment)
	local stray = environment.new("Folder", STRAY_FOLDER, environment.workspace)
	local inUse = environment.new("Folder", IN_USE_FOLDER, environment.workspace)

	-- 1) The first add's folder settles a category created with none, for later adds and for rebound
	cellar:create(CLAIMED)
	cellar:add(pool.template, nil, pool.folder, CLAIMED)
	cellar:add(pool.template, nil, nil, CLAIMED)

	local claimed: { any }? = cellar:get(CLAIMED_COUNT, CLAIMED)
	if not claimed or #claimed ~= CLAIMED_COUNT then
		return false, `{CLAIMED} held {claimed and #claimed or 0} copies, not {CLAIMED_COUNT}`
	end

	for _, copy: any in claimed do
		if copy.Parent ~= pool.folder then
			return false, `a copy in {CLAIMED} sits in {copy.Parent}, not the folder its first add named`
		end

		copy.Parent = inUse
		cellar:rebound(copy)

		if copy.Parent ~= pool.folder then
			return false, `a copy rebounded to {copy.Parent}, not the folder its category's first add named`
		end
	end

	-- 2) A first add that names no parent settles the category on the workspace
	cellar:create(UNSETTLED)
	cellar:add(pool.template, nil, nil, UNSETTLED)

	local unsettled: { any }? = cellar:get(nil, UNSETTLED)
	local settled: any = unsettled and unsettled[1]
	if not settled or settled.Parent ~= environment.workspace then
		return false, `a first add naming no parent did not settle {UNSETTLED} on the workspace`
	end

	-- 3) A later add naming another folder errors, naming both
	local refusedSettled: boolean, settledReason: string? =
		refuses(cellar, pool.template, stray, UNSETTLED, environment.workspace)
	if not refusedSettled then
		return false, settledReason
	end

	-- 4) A parent from create holds the same way
	cellar:create(DECLARED, pool.folder)
	cellar:add(pool.template, nil, nil, DECLARED)

	local declared: { any }? = cellar:get(nil, DECLARED)
	local copy: any = declared and declared[1]
	if not copy or copy.Parent ~= pool.folder then
		return false, `an add naming no parent did not land in the folder {DECLARED} was created with`
	end

	local refusedDeclared: boolean, declaredReason: string? =
		refuses(cellar, pool.template, stray, DECLARED, pool.folder)
	if not refusedDeclared then
		return false, declaredReason
	end

	return true, nil
end
