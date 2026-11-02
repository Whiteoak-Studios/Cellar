--[[
    Cellar, an instance pool: categories of copies cloned from a template,
    parked far below the map while idle, taken out with get and given back
    with rebound. One table per realm holds every category
--]]

--!strict
local Workspace = game:GetService("Workspace")

local PARK_CFRAME: CFrame = require(script.Constants).PARK_CFRAME

export type Copies = {
	idle: { Instance },
	out: { Instance },
}

type Category = {
	parent: Instance?, -- Where its copies live, settled by create or by the first add
	idle: { Instance }, -- Last in, first out: add and rebound put a copy on the end, get and remove take from there
	takes: number, -- How many copies get has taken, which numbers each take
}

type Out = {
	category: Category, -- The category rebound gives the copy back to
	take: number, -- Its place in the order get took the category's copies
}

--- @class Cellar
--- An instance pool. Each category is a name, the parent its copies live
--- in and a list of idle copies, and every category in a realm lives in
--- this one table

local Cellar = {
	_categories = {} :: { [string]: Category }, -- Every category, by its name
	_out = {} :: { [Instance]: Out }, -- Every copy taken with get, to its category and its place in the take order
}

--- Declares a category. Its copies live in `parent`, and a category
--- declared with none takes the first `add`'s. A second `create` of a
--- name warns, returns false and leaves the first category as it was.
--- @method create
--- @within Cellar
--- @param category string -- The category's name, which may carry slashes, as `FX/Casing/Rifle` does
--- @param parent Instance? -- Where the category's copies live
--- @return boolean -- False when the name is already a category

function Cellar.create(self: Self, category: string, parent: Instance?): boolean
	if self._categories[category] then
		warn(`Cellar:create was given {category}, which is already a category, and leaves it as it was`)
		return false
	end

	self._categories[category] = {
		parent = parent,
		idle = {},
		takes = 0,
	}

	return true
end

--[[
    Errors at the call when a count is given that is not a whole number of
    1 or more, naming the function and the value
--]]

local function checkCount(name: string, count: number?)
	if count and (count < 1 or count % 1 ~= 0) then
		error(`Cellar:{name} needs a count that is a whole number of 1 or more, not {count}`)
	end
end

--[[
    Moves a copy to the park point, a Model by its pivot and a part by its
    CFrame. Anything else stays where it is, so its owner stops it
--]]

local function park(copy: Instance)
	if copy:IsA("Model") then
		copy:PivotTo(PARK_CFRAME)
	elseif copy:IsA("BasePart") then
		copy.CFrame = PARK_CFRAME
	end
end

--- Clones `template` `count` times, once by default, and parks, parents
--- and adds each clone to the category's idle list before it returns. A
--- nil template, an unknown category, an unarchivable template or a
--- parent other than the category's errors at the call.
--- @method add
--- @within Cellar
--- @param template Instance -- What to clone, in the DataModel or not
--- @param count number? -- How many copies to make, a whole number of 1 or more
--- @param parent Instance? -- The category's parent, or nil for the one it has
--- @param category string -- The category the copies join
--- @return boolean -- True once every copy is on the idle list

function Cellar.add(self: Self, template: Instance, count: number?, parent: Instance?, category: string): boolean
	checkCount("add", count)

	if not template then
		error(`Cellar:add was given no template for {category}`)
	end

	local record: Category? = self._categories[category]
	if not record then
		error(`Cellar:add found no category {category}; create it first`)
	end

	-- Clone gives nil for an unarchivable instance
	if not template.Archivable then
		error(`Cellar:add cannot clone {template}, whose Archivable is false`)
	end

	-- The first add settles a category declared with no parent, on the workspace when it names none
	if not record.parent then
		record.parent = parent or Workspace
	elseif parent and parent ~= record.parent then
		error(`Cellar:add was given {parent} for {category}, whose copies live in {record.parent}`)
	end

	for _ = 1, count or 1 do
		local copy: Instance = template:Clone()
		park(copy)
		copy.Parent = record.parent
		table.insert(record.idle, copy)

		-- The copy owns this connection, which ends when the copy is destroyed
		copy.Destroying:Connect(function ()
			self._out[copy] = nil

			local index: number? = table.find(record.idle, copy)
			if index then
				table.remove(record.idle, index)
			end
		end)
	end

	return true
end

--- Takes up to `count` idle copies out, one by default, and marks them
--- out. With a `name` it takes only copies of that name. It takes from
--- the end of the idle list, and a named `get` scans the list once. An
--- idle copy whose `Parent` is nil was destroyed, so `get` drops it from
--- the list and never hands it out.
--- @method get
--- @within Cellar
--- @param count number? -- The most copies to take, a whole number of 1 or more
--- @param category string -- The category to take from
--- @param name string? -- Only copies of this name
--- @return { Instance }? -- The copies taken, or nil for an unknown category or when none is idle or of that name

function Cellar.get(self: Self, count: number?, category: string, name: string?): { Instance }?
	checkCount("get", count)

	local record: Category? = self._categories[category]
	if not record then
		return nil
	end

	local idle: { Instance } = record.idle
	local wanted: number = count or 1
	local taken: { Instance } = {}

	-- Walking down from the end, a removal shifts only copies already passed
	for index = #idle, 1, -1 do
		local copy: Instance = idle[index]

		-- An idle copy sits in its category's parent, so a nil Parent is a copy destroyed before its Destroying ran
		if not copy.Parent then
			table.remove(idle, index)
			continue
		end

		if name and copy.Name ~= name then
			continue
		end

		table.remove(idle, index)
		record.takes += 1
		self._out[copy] = {
			category = record,
			take = record.takes,
		}
		table.insert(taken, copy)

		if #taken == wanted then
			break
		end
	end

	return #taken > 0 and taken or nil
end

--[[
    Parents a copy, as its own function so rebound can guard the write
--]]

local function setParent(copy: Instance, parent: Instance?)
	copy.Parent = parent
end

--- Gives back a copy taken with `get`: parents it to its category's
--- parent, parks it and puts it on the end of the idle list. It resets
--- only position and parent. A copy that is not out, or was destroyed,
--- warns and returns false.
--- @method rebound
--- @within Cellar
--- @param copy Instance -- A copy taken with `get`
--- @return boolean -- False when the copy is not out or was destroyed

function Cellar.rebound(self: Self, copy: Instance): boolean
	local out: Out? = self._out[copy]
	if not out then
		warn(`Cellar:rebound was given {copy}, which is not out`)
		return false
	end

	local record: Category = out.category

	-- A destroyed copy's Parent is locked, and under deferred signals its Destroying may not have run yet
	local parented: boolean, reason: any = pcall(setParent, copy, record.parent)
	if not parented then
		warn(`Cellar:rebound could not give back {copy}: {reason}`)
		return false
	end

	park(copy)
	self._out[copy] = nil
	table.insert(record.idle, copy)

	return true
end

--- Destroys up to `count` idle copies, one by default, taking from the
--- end of the idle list, and leaves copies that are out alone. An unknown
--- category errors at the call, and one with no idle copy warns and
--- returns false.
--- @method remove
--- @within Cellar
--- @param category string -- The category to destroy idle copies of
--- @param count number? -- The most copies to destroy, a whole number of 1 or more
--- @return boolean -- False when no copy was idle

function Cellar.remove(self: Self, category: string, count: number?): boolean
	checkCount("remove", count)

	local record: Category? = self._categories[category]
	if not record then
		error(`Cellar:remove found no category {category}`)
	end

	local idle: { Instance } = record.idle
	if #idle == 0 then
		warn(`Cellar:remove found no idle copy in {category}`)
		return false
	end

	-- Each copy leaves the list before its Destroy, since Destroying may run at once
	for _ = 1, math.min(count or 1, #idle) do
		local copy = table.remove(idle) :: Instance
		copy:Destroy()
	end

	return true
end

--- Gives a category's copies as two fresh arrays, so changing them
--- changes nothing in the pool. `idle` keeps the idle list's order, so
--- its last entry is the next copy `get` takes, and `out` lists copies in
--- the order `get` took them. Each call allocates, so it belongs at boot
--- or on a settings change.
--- @method getAll
--- @within Cellar
--- @param category string -- The category to list
--- @return Copies? -- The idle and out copies, or nil for an unknown category

function Cellar.getAll(self: Self, category: string): Copies?
	local record: Category? = self._categories[category]
	if not record then
		return nil
	end

	-- Whiteoak TODO: this walks every out copy of every category; keep an out set per category if getAll runs hot
	local out: { Instance } = {}
	for copy: Instance, taken: Out in self._out do
		if taken.category == record then
			table.insert(out, copy)
		end
	end

	table.sort(out, function (first: Instance, second: Instance): boolean
		return self._out[first].take < self._out[second].take
	end)

	return {
		idle = table.clone(record.idle),
		out = out,
	}
end

type Self = typeof(Cellar)

return Cellar
